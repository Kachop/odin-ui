package rwb

import "base:runtime"
import "core:encoding/endian"
import "core:fmt"
import "core:io"
import os "core:os"
import "core:unicode/utf8"

//Logic for loading and utilising TTF fonts.
//Will read a .ttf file and parse all of the information necessary for font rendering.

TTF_Reader :: struct {
	cursor:     u32,
	buf:        []u8,
	len:        u32,
	tables:     map[string]u32,
	cmap:       map[rune]u32,
	glyf_data:  []Glyf_Data,
	glyf_count: u16,
	max_glyfs:  u16,
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
	x_min, y_min, x_max, y_max: i16,
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

		reader.glyf_data = make([]Glyf_Data, 1024, allocator = ui_alloc)

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

ttf_read_i16_arr :: proc(reader: ^TTF_Reader, arr: []i16, len: u32) {
	if reader.cursor < reader.len - 1 - (2 * len) {
		for i in 0 ..< len {
			arr[i], _ = endian.get_i16(reader.buf[reader.cursor:reader.cursor + 2], .Big)
			reader.cursor += 2
		}
	}
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

ttf_read_cmap :: proc(reader: ^TTF_Reader) {
	ttf_move_to_location(reader, reader.tables["cmap"])

	version := ttf_read_u16(reader)
	num_sub_tables := ttf_read_u16(reader)

	fmt.println("Version:", version, "\nNum of sub tables:", num_sub_tables)

	for i in 0 ..< num_sub_tables {
		platform_ID := ttf_read_u16(reader)
		platform_specific_ID := ttf_read_u16(reader)
		offset := ttf_read_u32(reader)

		fmt.println(
			"Platform ID:",
			platform_ID,
			"\nPlatform Specific ID:",
			platform_specific_ID,
			"\nOffset:",
			offset,
		)

		if platform_ID == 0 {
			//Found the unicode table
			ttf_move_to_location(reader, reader.tables["cmap"] + offset) //Offset seems to be from location of cmap table, not offset post reading info
			break
		}
	}

	//ttf_skip_bytes(reader, 28)
	format := ttf_read_u16(reader)
	//language := ttf_read_u16(reader)
	fmt.println("Format:", format)

	switch format {
	case 0:
	case 2:
	case 4:
		length := ttf_read_u16(reader)
		language := ttf_read_u16(reader)
		seg_count_X2 := ttf_read_u16(reader)
		seg_count := seg_count_X2 / 2
		search_range := ttf_read_u16(reader)
		entry_selector := ttf_read_u16(reader)
		range_shift := ttf_read_u16(reader)
		end_code := make([]u16, seg_count, allocator = ui_alloc)
		ttf_read_u16_arr(reader, end_code, cast(u32)seg_count)
		reserved_pad := ttf_read_u16(reader) //Should be 0
		start_code := make([]u16, seg_count, allocator = ui_alloc)
		ttf_read_u16_arr(reader, start_code, cast(u32)seg_count)
		id_delta := make([]i16, seg_count, allocator = ui_alloc)
		ttf_read_i16_arr(reader, id_delta, cast(u32)seg_count)
		id_range_offset := make([]u16, seg_count, allocator = ui_alloc)
		reader_loc := reader.cursor //location set to start of range offset array
		ttf_read_u16_arr(reader, id_range_offset, cast(u32)seg_count)
		fmt.println(
			"length:",
			length,
			"\nlanguage:",
			language,
			"\nSeg count:",
			seg_count,
			"\nSearch range:",
			search_range,
			"\nRange shift:",
			range_shift,
			"\nReserved pad:",
			reserved_pad,
		)

		for i in 0 ..< seg_count {
			fmt.println("Segment", i + 1)
			fmt.println(
				"End code:",
				end_code[i],
				"\nStart code:",
				start_code[i],
				"\nidDelta:",
				id_delta[i],
				"\nidRangeOffset:",
				id_range_offset[i],
				"\n",
			)
			for c in start_code[i] ..= end_code[i] { 	//c = character code
				ttf_move_to_location(
					reader,
					reader_loc +
					(16 * cast(u32)(cast(i16)c + id_delta[i] + cast(i16)id_range_offset[i])),
				)
				rune_loc := ttf_read_u16(reader)

				if id_range_offset[i] == 0 {
					reader.cmap[rune(c)] = cast(u32)(id_delta[i] + cast(i16)c) //Set the index for the rune which is used to look-up into the offset array
				} else {
					ttf_move_to_location(
						reader,
						reader_loc +
						cast(u32)(i * 2) +
						cast(u32)(id_range_offset[i] / 2) +
						cast(u32)(c - start_code[i]),
					)
					glyf_index := ttf_read_u16(reader)

					if glyf_index != 0 {
						glyf_index = cast(u16)(cast(i16)glyf_index + id_delta[i])
						reader.cmap[rune(c)] = cast(u32)glyf_index
					} else {
						fmt.println("Glyf not mapped")
					}
				}
			}
		}
		fmt.println("Number of runes:", len(runes))

	case 6:
	case 8:
	case 10:
	case 12:
	case 14:
	}

}

runes: [dynamic]rune

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
	fmt.println("Reading glyf @", reader.cursor)
	num_of_contours := ttf_read_i16(reader)
	x_min := ttf_read_i16(reader)
	y_min := ttf_read_i16(reader)
	x_max := ttf_read_i16(reader)
	y_max := ttf_read_i16(reader)

	fmt.println("Num of contours:", num_of_contours)

	if num_of_contours == 0 {
		//Non-visual character, can skip the rest, no data exists
		return
	} else if num_of_contours < 0 {
		fmt.println("Compound glyf found")
	}

	end_pts_of_contours := make([]u16, num_of_contours, ui_alloc)
	ttf_read_u16_arr(reader, end_pts_of_contours, cast(u32)num_of_contours)
	fmt.println("End contour points:", end_pts_of_contours)
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

	reader.glyf_data[reader.glyf_count] = Glyf_Data {
		num_of_contours,
		x_min,
		y_min,
		x_max,
		y_max,
		end_pts_of_contours,
		instructions_len,
		instructions,
		flags,
		x_coords,
		y_coords,
	}

	reader.glyf_count += 1
}

load_font :: proc(filepath: string) -> TTF_Reader {
	ttf_reader: TTF_Reader

	load_ttf(&ttf_reader, filepath)

	scalar_type := ttf_read_u32(&ttf_reader)
	num_tables := ttf_read_u16(&ttf_reader)
	search_range := ttf_read_u16(&ttf_reader)
	entry_selector := ttf_read_u16(&ttf_reader)
	range_shifter := ttf_read_u16(&ttf_reader)

	fmt.println("Number of tables:", num_tables)
	fmt.println("Search range", search_range)

	ttf_reader.tables = make(map[string]u32, allocator = ui_alloc) //map[table_name]location
	ttf_reader.cmap = make(map[rune]u32, allocator = ui_alloc)

	for _ in 1 ..= num_tables {
		tag := ttf_read_tag(&ttf_reader)
		check_sum := ttf_read_u32(&ttf_reader)
		offset := ttf_read_u32(&ttf_reader)
		length := ttf_read_u32(&ttf_reader)
		ttf_reader.tables[tag] = offset
	}
	fmt.println(ttf_reader.tables)

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["maxp"])

	version := ttf_read_u32(&ttf_reader)
	ttf_reader.max_glyfs = ttf_read_u16(&ttf_reader)

	fmt.println("Max glyfs:", ttf_reader.max_glyfs)

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["head"])

	ttf_skip_bytes(&ttf_reader, 46)
	lowest_rec_PPEM := ttf_read_u16(&ttf_reader)
	font_direction_hint := ttf_read_i16(&ttf_reader)
	loc_format := ttf_read_i16(&ttf_reader) //0 for short, 1 for long
	fmt.println(
		"PPEM:",
		lowest_rec_PPEM,
		"font direction:",
		font_direction_hint,
		"loc format:",
		loc_format,
	)

	ttf_read_cmap(&ttf_reader)

	fmt.println("Rune 65535", rune(64257))

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["loca"])

	offsets := make([]u16, ttf_reader.max_glyfs + 1, allocator = ui_alloc)

	if loc_format == 0 {
		//short format table
		ttf_read_u16_arr(&ttf_reader, offsets, cast(u32)ttf_reader.max_glyfs + 1)

		for offset, i in offsets {
			offsets[i] *= 2
		}

		fmt.println("Offsets:", offsets)

		fmt.println("Offsets:", len(offsets) - 1, ", Runes:", len(runes))

		//for offset, i in offsets[:len(offsets) - 1] {
		//	ttf_reader.cmap[runes[i]] = cast(u32)offset
		//}
	} else if loc_format == 1 {
		//long format table
	}

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["glyf"])
	//ttf_skip_bytes(&ttf_reader, 60)

	fmt.println("glyf_count:", ttf_reader.glyf_count)
	ttf_read_glyf_data(&ttf_reader)

	fmt.println("glyf_count:", ttf_reader.glyf_count)
	ttf_read_glyf_data(&ttf_reader)

	//fmt.println("glyf_count:", ttf_reader.glyf_count)
	//ttf_move_to_location(&ttf_reader, ttf_reader.tables["glyf"])
	//ttf_skip_bytes(&ttf_reader, ttf_reader.cmap['c'])
	//ttf_read_glyf_data(&ttf_reader)

	fmt.println("glyf_count:", ttf_reader.glyf_count)
	ttf_move_to_location(&ttf_reader, ttf_reader.tables["glyf"])
	ttf_skip_bytes(&ttf_reader, cast(u32)offsets[ttf_reader.cmap['e']])
	ttf_read_glyf_data(&ttf_reader)

	//ttf_skip_bytes(&ttf_reader, 7)
	//ttf_read_glyf_data(&ttf_reader)

	return ttf_reader
}

draw_glyf :: proc(x, y: f32, glyf_data: Glyf_Data) {
	//Take the glyf data and build the list of vertices and indices before sending the draw command
	//num_of_contours := glyf_data.num_of_contours
	//contour_end_points := glyf_data.end_pts_of_contours

	x, y := x, y

	//vertices: [dynamic]Point
	off_curve_counter: u8

	for flag, i in glyf_data.flags {

		offset_x := glyf_data.x_coords[i]
		offset_y := glyf_data.y_coords[i]

		switch t in offset_x {
		case u8:
			x += cast(f32)offset_x.(u8) / 8
		case i16:
			x += cast(f32)offset_x.(i16) / 8
		}

		switch t in offset_y {
		case u8:
			y -= cast(f32)offset_y.(u8) / 8
		case i16:
			y -= cast(f32)offset_y.(i16) / 8
		}

		if ttf_is_flag_set(flag, 1) {
			//On-curve point

			off_curve_counter = 0

			fmt.println("Drawing point @", x, y)

			draw_point(x, y, 5)
		} else {
			//Off-curve point. 2 in a row means a point needs to be inserted in between.
			off_curve_counter += 1

			if off_curve_counter == 2 {
				//On-curve point needs inserting in between.
				off_curve_counter = 1
				temp_x, temp_y: f32 = x, y

				switch t in offset_x {
				case u8:
					temp_x -= cast(f32)offset_x.(u8) / 16
				case i16:
					temp_x -= cast(f32)offset_x.(i16) / 16
				}

				switch t in offset_y {
				case u8:
					temp_y += cast(f32)offset_y.(u8) / 16
				case i16:
					temp_y += cast(f32)offset_y.(i16) / 16
				}

				draw_point(temp_x, temp_y, 5)
			}
		}
	}
}
