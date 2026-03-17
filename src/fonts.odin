package rwb

import "base:runtime"
import "core:encoding/endian"
import "core:fmt"
import "core:io"
import os "core:os/os2"
import "core:unicode/utf8"

//Logic for loading and utilising TTF fonts.
//Will read a .ttf file and parse all of the information necessary for font rendering.

TTF_Reader :: struct {
	cursor: u32,
	buf:    []u8,
	len:    u32,
}

Glyf_Coord :: union {
	u8,
	i16,
}

Coord_Type :: enum {
	X,
	Y,
}

Glyf_Data :: struct {
	num_of_contours:            i16,
	x_min, y_min, x_max, y_max: u16,
	end_pts_of_contours:        []u16,
	instruction_length:         u16,
	instructions:               []u8,
	flags:                      []u8,
	x_coords, y_coords:         []Glyf_Coord,
}

load_ttf :: proc(reader: ^TTF_Reader, filename: string) {
	if os.exists(filename) {
		file_error: os.Error
		reader.buf, file_error = os.read_entire_file_from_path(filename, allocator = frame_alloc)

		if file_error == os.ERROR_NONE {
			fmt.println("Font Loaded", len(reader.buf), "bytes.")
			reader.len = cast(u32)len(reader.buf)
		} else {
			fmt.println("Error loading font:", file_error)
		}
	} else {
		fmt.println("File doesn't exist'")
	}
}

ttf_read_u8 :: proc(reader: ^TTF_Reader) -> u8 {
	if reader.cursor < reader.len - 2 {
		val := reader.buf[reader.cursor]
		reader.cursor += 1

		return val
	}
	return 0
}

ttf_read_u8_arr :: proc(reader: ^TTF_Reader, arr: []u8, len: u32) {
	if reader.cursor < reader.len - 1 - len {
		for i in 0 ..< len {
			arr[i] = reader.buf[reader.cursor]
			reader.cursor += 1
		}
	}
}

ttf_read_u16 :: proc(reader: ^TTF_Reader) -> u16 {
	if reader.cursor < reader.len - 3 {
		val, _ := endian.get_u16(reader.buf[reader.cursor:reader.cursor + 2], .Big)
		reader.cursor += 2

		return val
	}
	return 0
}

ttf_read_u16_arr :: proc(reader: ^TTF_Reader, arr: []u16, len: u32) {
	if reader.cursor < reader.len - 1 - (2 * len) {
		for i in 0 ..< len {
			arr[i], _ = endian.get_u16(reader.buf[reader.cursor:reader.cursor + 2], .Big)
			reader.cursor += 2
		}
	}
}

ttf_read_i16 :: proc(reader: ^TTF_Reader) -> i16 {
	if reader.cursor < reader.len - 3 {
		val, _ := endian.get_i16(reader.buf[reader.cursor:reader.cursor + 2], .Big)
		reader.cursor += 2

		return val
	}
	return 0
}

ttf_read_u32 :: proc(reader: ^TTF_Reader) -> u32 {
	if reader.cursor < reader.len - 5 {
		val, _ := endian.get_u32(reader.buf[reader.cursor:reader.cursor + 4], .Big)
		reader.cursor += 4

		return val
	}
	return 0
}

ttf_read_tag :: proc(reader: ^TTF_Reader) -> string {
	tag_u32 := ttf_read_u32(reader)

	byte_mask: u32 = 0b11111111
	runes := [4]rune {
		rune(tag_u32 >> 24 & byte_mask),
		rune(tag_u32 >> 16 & byte_mask),
		rune(tag_u32 >> 8 & byte_mask),
		rune(tag_u32 & byte_mask),
	}

	return utf8.runes_to_string(runes[:])
}

ttf_skip_bytes :: proc(reader: ^TTF_Reader, num_bytes: u32) {
	if reader.cursor < reader.len - 1 - num_bytes {
		reader.cursor += num_bytes
	}
}

ttf_move_to_location :: proc(reader: ^TTF_Reader, location: u32) {
	if location < reader.len - 1 {
		reader.cursor = location
	}
}

ttf_is_flag_set :: proc(flag: byte, bit_index: u8) -> bool {
	return ((flag >> bit_index) & 1) == 1
}

ttf_get_coords :: proc(
	reader: ^TTF_Reader,
	coords: []Glyf_Coord,
	num_of_coords: u16,
	flags: []u8,
	coord_type: Coord_Type,
) {
	for i in 0 ..< num_of_coords {
		flag := flags[i]
		switch coord_type {
		case .X:
			if ttf_is_flag_set(flag, 1) {
				if ttf_is_flag_set(flag, 4) {
					//Possitive 1 byte coord. (u8)
					coords[i] = ttf_read_u8(reader)
				} else {
					//Negative 1 byte coord. (i16)
					val := ttf_read_u8(reader)
					coords[i] = cast(i16)val * -1
				}
			} else {
				if ttf_is_flag_set(flag, 4) {
					//Skip offset (value is 0)
					coords[i] = cast(i16)0
				} else {
					//Use offset
					coords[i] = ttf_read_i16(reader)
				}
			}
		case .Y:
			if ttf_is_flag_set(flag, 2) {
				if ttf_is_flag_set(flag, 5) {
					//Possitive 1 byte coord. (u8)
					coords[i] = ttf_read_u8(reader)
				} else {
					//Negative 1 byte coord. (i16)
					val := ttf_read_u8(reader)
					coords[i] = cast(i16)val * -1
				}
			} else {
				if ttf_is_flag_set(flag, 5) {
					//Skip offset
					coords[i] = cast(i16)0
				} else {
					//Use offset
					coords[i] = ttf_read_i16(reader)
				}
			}
		}
	}
}

ttf_read_glyf_data :: proc(reader: ^TTF_Reader) {
	num_of_contours := ttf_read_i16(reader)
	x_min := ttf_read_u16(reader)
	y_min := ttf_read_u16(reader)
	x_max := ttf_read_u16(reader)
	y_max := ttf_read_u16(reader)
	end_pts_of_contours := make([]u16, num_of_contours, ui_alloc)
	ttf_read_u16_arr(reader, end_pts_of_contours, cast(u32)num_of_contours)
	instructions_len := ttf_read_u16(reader)
	instructions := make([]u8, instructions_len, ui_alloc)
	ttf_read_u8_arr(reader, instructions, cast(u32)instructions_len)

	num_of_coords := end_pts_of_contours[num_of_contours - 1] + 1

	flags := make([]u8, num_of_coords, ui_alloc)

	i: u16 = 0

	for i < num_of_coords {
		flag := ttf_read_u8(reader)

		flags[i] = flag

		if ttf_is_flag_set(flag, 3) {
			repeats := ttf_read_u8(reader)
			for r: u8 = 0; r < repeats; r += 1 {
				i += 1
				flags[i] = flag
			}
		}

		i += 1
	}

	fmt.println(
		"Glyf Data\n- Num of contours:",
		num_of_contours,
		"\n- Contour end pts:",
		end_pts_of_contours,
		"\n- Flags:",
		flags,
	)

	x_coords := make([]Glyf_Coord, num_of_coords, ui_alloc)
	y_coords := make([]Glyf_Coord, num_of_coords, ui_alloc)

	ttf_get_coords(reader, x_coords, num_of_coords, flags, .X)
	ttf_get_coords(reader, y_coords, num_of_coords, flags, .Y)

	fmt.println("Coords:")

	for i in 0 ..< num_of_coords {
		fmt.println(i, "| x:", x_coords[i], ", y:", y_coords[i])
	}
}

load_font :: proc(filepath: string) {
	ttf_reader: TTF_Reader

	load_ttf(&ttf_reader, filepath)

	scalar_type := ttf_read_u32(&ttf_reader)
	num_tables := ttf_read_u16(&ttf_reader)
	search_range := ttf_read_u16(&ttf_reader)
	entry_selector := ttf_read_u16(&ttf_reader)
	range_shifter := ttf_read_u16(&ttf_reader)

	fmt.println("Number of tables:", num_tables)
	fmt.println("Search range", search_range)

	tables: map[string]u32 //map[table_name]location

	for _ in 1 ..= num_tables {
		tag := ttf_read_tag(&ttf_reader)
		check_sum := ttf_read_u32(&ttf_reader)
		offset := ttf_read_u32(&ttf_reader)
		length := ttf_read_u32(&ttf_reader)
		tables[tag] = offset
	}
	fmt.println(tables)

	ttf_move_to_location(&ttf_reader, tables["glyf"])

	ttf_read_glyf_data(&ttf_reader)
}
