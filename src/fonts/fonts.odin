package font

import platform "../platform"
import renderer "../renderer"
import "core:encoding/endian"
import "core:flags"
import "core:flags/example"
import "core:fmt"
import "core:io"
import "core:mem"
import vmem "core:mem/virtual"
import os "core:os"
import "core:unicode/utf8"

//Logic for loading and utilising TTF fonts.
//Will read a .ttf file and parse all of the information necessary for font rendering.
Font :: struct {
	base_size:  int,
	glyf_count: int,
	glyf_info:  map[rune]Glyf_Data, //Bezier points calculated
	arena:      vmem.Arena,
	allocator:  mem.Allocator,
}

TTF_Reader :: struct {
	cursor:    u32, //Current reading location.
	buf:       []u8, //TTF file data.
	len:       u32, //Total file length (for bounds checking).
	tables:    map[string]u32, //All of the tables from the TTF file.
	cmap:      map[rune]u32, //All of the character mappings.
	max_glyfs: u16, //Max number of glyfs.
	arena:     vmem.Arena, //Arena for all the reader opperations.
	allocator: mem.Allocator, //Everything can be disposed of once the file is read.
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
	em_coords_x, em_coords_y:   []f32,
	cached:                     bool,
	bezier_curve_points:        [][]renderer.Point, //calculated the first time the glyf is drawn
	units_per_em:               u16,
	allocator:                  mem.Allocator,
}

init_ttf_reader :: proc(ttf_reader: ^TTF_Reader) {
	@(static) ttf_arean: vmem.Arena
	@(static) ttf_alloc: mem.Allocator

	arena_err := vmem.arena_init_static(&ttf_arean, 50 * mem.Megabyte)
	if arena_err == .None {
		ttf_alloc = vmem.arena_allocator(&ttf_arean)
	}

	ttf_reader.arena = ttf_arean
	ttf_reader.allocator = ttf_alloc

	ttf_reader.tables = make(map[string]u32, ttf_reader.allocator)
	ttf_reader.cmap = make(map[rune]u32, ttf_reader.allocator)

	fmt.println("TTF alloc:", ttf_reader.arena.total_reserved, ttf_reader.arena.total_used)
}

destroy_ttf_reader :: proc(ttf_reader: ^TTF_Reader) {
	delete_map(ttf_reader.tables)
	delete_map(ttf_reader.cmap)
	vmem.arena_free_all(&ttf_reader.arena)
}

init_font :: proc(font: ^Font) {
	@(static) font_arena: vmem.Arena
	@(static) font_alloc: mem.Allocator

	arena_err := vmem.arena_init_static(&font_arena, 50 * mem.Megabyte)
	if arena_err == .None {
		font_alloc = vmem.arena_allocator(&font_arena)
	}

	font.arena = font_arena
	font.allocator = font_alloc
}

destroy_font :: proc(font: ^Font) {
	vmem.arena_free_all(&font.arena)
}

load_ttf_file :: proc(reader: ^TTF_Reader, filename: string) {
	if os.exists(filename) {
		file_error: os.Error
		reader.buf, file_error = os.read_entire_file_from_path(
			filename,
			allocator = reader.allocator,
		)

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

ttf_read_u32_arr :: proc(reader: ^TTF_Reader, arr: []u32, len: u32) {
	if reader.cursor < reader.len - 1 - (4 * len) {
		for i in 0 ..< len {
			arr[i], _ = endian.get_u32(reader.buf[reader.cursor:reader.cursor + 4], .Big)
			reader.cursor += 4
		}
	}
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
		//TODO: Implement stuff for other platforms
	}

	format := ttf_read_u16(reader)

	switch format {
	case 0:
		fmt.println("ERROR: FORMAT 0 CMAP NOT IMPLEMENTED")
	case 2:
		fmt.println("ERROR: FORMAT 2 CMAP NOT IMPLEMENTED")
	case 4:
		length := ttf_read_u16(reader)
		language := ttf_read_u16(reader)
		seg_count_X2 := ttf_read_u16(reader)
		seg_count := seg_count_X2 / 2
		search_range := ttf_read_u16(reader)
		entry_selector := ttf_read_u16(reader)
		range_shift := ttf_read_u16(reader)
		end_code := make([]u16, seg_count, allocator = reader.allocator)
		ttf_read_u16_arr(reader, end_code, cast(u32)seg_count)
		reserved_pad := ttf_read_u16(reader) //Should be 0
		start_code := make([]u16, seg_count, allocator = reader.allocator)
		ttf_read_u16_arr(reader, start_code, cast(u32)seg_count)
		id_delta := make([]i16, seg_count, allocator = reader.allocator)
		ttf_read_i16_arr(reader, id_delta, cast(u32)seg_count)
		id_range_offset := make([]u16, seg_count, allocator = reader.allocator)
		reader_loc := reader.cursor //location set to start of range offset array
		ttf_read_u16_arr(reader, id_range_offset, cast(u32)seg_count)

		for i in 0 ..< seg_count {
			for c in start_code[i] ..= end_code[i] { 	//c = character code	
				if id_range_offset[i] == 0 {
					//if (id_delta[i] + cast(i16)c) < 0 {
					//reader.cmap[rune(c)] = cast(u32)(id_delta[i] + cast(i16)c) + 65536
					//} else {
					reader.cmap[rune(c)] = cast(u32)(id_delta[i] + cast(i16)c) % 65536 //Set the index for the rune which is used to look-up into the offset array
					//}
				} else {
					ttf_move_to_location(
						reader,
						reader_loc +
						cast(u32)(i * 2) +
						cast(u32)(2 * (c - start_code[i])) +
						cast(u32)(id_range_offset[i]),
					)
					glyf_index_offset := ttf_read_u16(reader)

					if glyf_index_offset != 0 {
						glyf_index := cast(u32)(cast(i16)glyf_index_offset + id_delta[i]) % 65536
						reader.cmap[rune(c)] = cast(u32)glyf_index
					} else {
						//Glyf not mapped.
						reader.cmap[rune(c)] = 0
					}
				}
			}
		}
	case 6:
		fmt.println("ERROR: FORMAT 6 CMAP NOT IMPLEMENTED")
	case 8:
		fmt.println("ERROR: FORMAT 8 CMAP NOT IMPLEMENTED")
	case 10:
		fmt.println("ERROR: FORMAT 10 CMAP NOT IMPLEMENTED")
	case 12:
		fmt.println("ERROR: FORMAT 12 CMAP NOT IMPLEMENTED")
	case 14:
		fmt.println("ERROR: FORMAT 14 CMAP NOT IMPLEMENTED")
	}

}

//runes: [dynamic]rune

ttf_get_em_coords :: proc(
	reader: ^TTF_Reader,
	coords: []f32,
	num_of_coords: u16,
	flags: []u8,
	coord_type: Coord_Type,
) {
	//Turns the coordinate offsets into an array of glyf coordinates in em space.
	coord_offsets := make([]i16, num_of_coords, allocator = reader.allocator)

	for i in 0 ..< num_of_coords {
		flag := flags[i]
		switch coord_type {
		case .X:
			if ttf_is_flag_set(flag, 1) {
				if ttf_is_flag_set(flag, 4) {
					//Possitive 1 byte coord. (u8)
					coord_offsets[i] = cast(i16)ttf_read_u8(reader)
				} else {
					//Negative 1 byte coord. (i16)
					val := ttf_read_u8(reader)
					coord_offsets[i] = cast(i16)val * -1
				}
			} else {
				if ttf_is_flag_set(flag, 4) {
					//Skip offset (value is 0)
					coord_offsets[i] = cast(i16)0
				} else {
					//Use offset
					coord_offsets[i] = ttf_read_i16(reader)
				}
			}
		case .Y:
			if ttf_is_flag_set(flag, 2) {
				if ttf_is_flag_set(flag, 5) {
					//Possitive 1 byte coord. (u8)
					coord_offsets[i] = cast(i16)ttf_read_u8(reader)
				} else {
					//Negative 1 byte coord. (i16)
					val := ttf_read_u8(reader)
					coord_offsets[i] = cast(i16)val * -1
				}
			} else {
				if ttf_is_flag_set(flag, 5) {
					//Skip offset
					coord_offsets[i] = cast(i16)0
				} else {
					//Use offset
					coord_offsets[i] = ttf_read_i16(reader)
				}
			}
		}
	}

	coord: f32

	for i in 0 ..< num_of_coords {
		switch coord_type {
		case .X:
			coord += (cast(f32)coord_offsets[i])
		case .Y:
			coord -= (cast(f32)coord_offsets[i])
		}
		coords[i] = coord
	}
}

ttf_read_glyf_data :: proc(
	reader: ^TTF_Reader,
	units_per_em: u16,
	allocator: mem.Allocator,
) -> Glyf_Data {
	num_of_contours := ttf_read_i16(reader)
	x_min := ttf_read_i16(reader)
	y_min := ttf_read_i16(reader)
	x_max := ttf_read_i16(reader)
	y_max := ttf_read_i16(reader)

	if num_of_contours == 0 {
		//Non-visual character, can skip the rest, no data exists
		return Glyf_Data {
			num_of_contours,
			x_min,
			y_min,
			x_max,
			y_max,
			{},
			0,
			{},
			{},
			{},
			{},
			false,
			{},
			0,
			allocator,
		}
	} else if num_of_contours < 0 {
		//Compound glyf. TODO: Implement
		fmt.println("ERROR: COMPOUND GLYFS NOT IMPLEMENTED")
		return {}
	}

	end_pts_of_contours := make([]u16, num_of_contours, allocator = allocator)
	ttf_read_u16_arr(reader, end_pts_of_contours, cast(u32)num_of_contours)
	//fmt.println("End contour points:", end_pts_of_contours)
	instructions_len := ttf_read_u16(reader)
	instructions := make([]u8, instructions_len, allocator = allocator)
	ttf_read_u8_arr(reader, instructions, cast(u32)instructions_len)

	num_of_coords := end_pts_of_contours[num_of_contours - 1] + 1

	flags := make([]u8, num_of_coords, allocator = allocator)

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

	x_coords := make([]f32, num_of_coords, allocator = allocator)
	y_coords := make([]f32, num_of_coords, allocator = allocator)

	ttf_get_em_coords(reader, x_coords, num_of_coords, flags, .X)
	ttf_get_em_coords(reader, y_coords, num_of_coords, flags, .Y)

	return Glyf_Data {
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
		false,
		{},
		units_per_em,
		allocator,
	}
}

ttf_load_font :: proc(filepath: string) -> Font {
	font: Font
	init_font(&font)

	ttf_reader: TTF_Reader

	init_ttf_reader(&ttf_reader)
	load_ttf_file(&ttf_reader, filepath)

	scalar_type := ttf_read_u32(&ttf_reader)
	num_tables := ttf_read_u16(&ttf_reader)
	search_range := ttf_read_u16(&ttf_reader)
	entry_selector := ttf_read_u16(&ttf_reader)
	range_shifter := ttf_read_u16(&ttf_reader)

	for _ in 1 ..= num_tables {
		tag := ttf_read_tag(&ttf_reader)
		check_sum := ttf_read_u32(&ttf_reader)
		offset := ttf_read_u32(&ttf_reader)
		length := ttf_read_u32(&ttf_reader)
		ttf_reader.tables[tag] = offset
	}

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["maxp"])

	version := ttf_read_u32(&ttf_reader)
	ttf_reader.max_glyfs = ttf_read_u16(&ttf_reader)

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["head"])

	ttf_skip_bytes(&ttf_reader, 18)
	units_per_em := ttf_read_u16(&ttf_reader)
	ttf_skip_bytes(&ttf_reader, 26)
	lowest_rec_PPEM := ttf_read_u16(&ttf_reader)
	font_direction_hint := ttf_read_i16(&ttf_reader)
	loc_format := ttf_read_i16(&ttf_reader) //0 for short, 1 for long
	ttf_read_cmap(&ttf_reader)

	//fmt.println("Rune 65535", rune(64257))

	ttf_move_to_location(&ttf_reader, ttf_reader.tables["loca"])

	offsets := make([]u32, ttf_reader.max_glyfs + 1, allocator = ttf_reader.allocator)

	if loc_format == 0 {
		//short format table
		temp_offsets := make([]u16, ttf_reader.max_glyfs + 1, allocator = ttf_reader.allocator)
		ttf_read_u16_arr(&ttf_reader, temp_offsets, cast(u32)ttf_reader.max_glyfs + 1)

		for offset, i in temp_offsets {
			offsets[i] = cast(u32)temp_offsets[i] * 2
		}
	} else if loc_format == 1 {
		ttf_read_u32_arr(&ttf_reader, offsets, cast(u32)ttf_reader.max_glyfs + 1)
	}

	glyf_info := make(map[rune]Glyf_Data, allocator = context.allocator)

	for key, val in ttf_reader.cmap {
		ttf_move_to_location(&ttf_reader, ttf_reader.tables["glyf"])
		ttf_skip_bytes(&ttf_reader, cast(u32)offsets[val])
		glyf_info[key] = ttf_read_glyf_data(&ttf_reader, units_per_em, font.allocator)
	}

	font.base_size = cast(int)lowest_rec_PPEM
	font.glyf_count = cast(int)ttf_reader.max_glyfs
	font.glyf_info = glyf_info

	destroy_ttf_reader(&ttf_reader)

	//fmt.println("FINISHED LOADING FONT")
	return font
}

linear_interpolation :: proc(start, end: renderer.Point, t: f32) -> renderer.Point {
	return start + (end - start) * t
}

bezier_interpolation :: proc(p0, p1, p2: renderer.Point, t: f32) -> renderer.Point {
	intermediate_A := linear_interpolation(p0, p1, t)
	intermediate_B := linear_interpolation(p1, p2, t)
	return linear_interpolation(intermediate_A, intermediate_B, t)
}

calculate_bezier :: proc(p0, p1, p2: renderer.Point, resolution: int) -> []renderer.Point {
	points: [dynamic]renderer.Point

	for i := 0; i < resolution; i += 1 {
		t: f32 = (cast(f32)(i + 1) / cast(f32)resolution)
		next_point_on_curve := bezier_interpolation(p0, p1, p2, t)
		append(&points, next_point_on_curve)
	}
	return points[:]
}

calculate_curve_points :: proc(glyf_data: ^Glyf_Data) {
	//For non-cached glyfs. Calculate the curve points so the line segments can be drawn. Add curve points to the glyf data.
	num_of_contours := glyf_data.num_of_contours
	contour_end_points := glyf_data.end_pts_of_contours

	curve_points := make([dynamic]renderer.Point, allocator = context.temp_allocator)
	curve_contour_end_points := make([dynamic]int, allocator = context.temp_allocator)

	current_contour: u8
	on_curve_counter: u8
	off_curve_counter: u8

	//pixel coord = em_coord * ppem / upem
	scale_multiplyer: f32 = (6 * 10) / cast(f32)glyf_data.units_per_em

	contour_start := 0

	for end_index in glyf_data.end_pts_of_contours {
		on_curve_offset: int //Offset to first on-curve point.
		for i in contour_start ..< cast(int)end_index {
			if ttf_is_flag_set(glyf_data.flags[i], 0) {
				on_curve_offset = i - contour_start
				break
			}
		}

		for i in contour_start + on_curve_offset ..= cast(int)end_index + on_curve_offset {
			index := i
			if i > cast(int)end_index { 	//If the end of the array is reached now index from the start
				index -= (cast(int)end_index - contour_start) + 1
			}
			x_coord := glyf_data.em_coords_x[index]
			y_coord := glyf_data.em_coords_y[index]

			if ttf_is_flag_set(glyf_data.flags[index], 0) {
				//fmt.println(index, "On curve")
				//On curve point
				off_curve_counter = 0
				on_curve_counter += 1

				if on_curve_counter == 2 {
					on_curve_counter = 1

					if index == contour_start {
						append(
							&curve_points,
							renderer.Point {
								((cast(f32)x_coord + cast(f32)glyf_data.em_coords_x[end_index])) *
								(scale_multiplyer / 2),
								((cast(f32)y_coord + cast(f32)glyf_data.em_coords_y[end_index])) *
								(scale_multiplyer / 2),
							},
						)
					} else {
						append(
							&curve_points,
							renderer.Point {
								((cast(f32)x_coord + cast(f32)glyf_data.em_coords_x[index - 1]) *
									(scale_multiplyer / 2)),
								((cast(f32)y_coord + cast(f32)glyf_data.em_coords_y[index - 1]) *
									(scale_multiplyer / 2)),
							},
						)
					}
				}
				append(
					&curve_points,
					renderer.Point {
						(cast(f32)x_coord * scale_multiplyer),
						(cast(f32)y_coord * scale_multiplyer),
					},
				)
			} else {
				//fmt.println(index, "Off curve")
				//Off curve point
				on_curve_counter = 0
				off_curve_counter += 1

				if off_curve_counter == 2 {
					//On-curve point needs inserting in between.
					off_curve_counter = 1

					if index == contour_start {
						append(
							&curve_points,
							renderer.Point {
								((cast(f32)x_coord + cast(f32)glyf_data.em_coords_x[end_index])) *
								(scale_multiplyer / 2),
								((cast(f32)y_coord + cast(f32)glyf_data.em_coords_y[end_index])) *
								(scale_multiplyer / 2),
							},
						)
					} else {
						append(
							&curve_points,
							renderer.Point {
								((cast(f32)x_coord + cast(f32)glyf_data.em_coords_x[index - 1]) *
									(scale_multiplyer / 2)),
								((cast(f32)y_coord + cast(f32)glyf_data.em_coords_y[index - 1]) *
									(scale_multiplyer / 2)),
							},
						)
					}
				}
				append(
					&curve_points,
					renderer.Point {
						(cast(f32)x_coord * scale_multiplyer),
						(cast(f32)y_coord * scale_multiplyer),
					},
				)
			}
		}

		on_curve_counter = 0
		off_curve_counter = 0

		if on_curve_offset == 0 && ttf_is_flag_set(glyf_data.flags[end_index], 0) {
			if len(curve_contour_end_points) > 0 {
				append(
					&curve_points,
					(curve_points[len(curve_points) - 1] +
						curve_points[curve_contour_end_points[len(curve_contour_end_points) - 1] + 1]) /
					2,
				)
			} else {
				append(&curve_points, (curve_points[len(curve_points) - 1] + curve_points[0]) / 2)
			}
		}

		contour_start = cast(int)end_index + 1

		append(&curve_contour_end_points, len(curve_points) - 1)
	}

	fmt.println(curve_contour_end_points)

	current_contour = 0

	bezier_curve_points := make([dynamic][]renderer.Point, allocator = glyf_data.allocator)
	current_contour_curve_points := make([dynamic]renderer.Point, allocator = glyf_data.allocator)

	contour_start = 0

	for end_index in curve_contour_end_points {
		for index := contour_start + 2; index < end_index; index += 2 {
			bezier_points := calculate_bezier(
				curve_points[index - 2],
				curve_points[index - 1],
				curve_points[index],
				30,
			)

			for point in bezier_points {
				append(&current_contour_curve_points, point)
			}
		}

		for point in calculate_bezier(
			curve_points[end_index - 1],
			curve_points[end_index],
			curve_points[contour_start],
			30,
		) {
			append(&current_contour_curve_points, point)
		}

		append(&bezier_curve_points, current_contour_curve_points[:])
		current_contour_curve_points = make(
			[dynamic]renderer.Point,
			allocator = glyf_data.allocator,
		)
		contour_start = end_index + 1
	}
	glyf_data.bezier_curve_points = bezier_curve_points[:]
}
