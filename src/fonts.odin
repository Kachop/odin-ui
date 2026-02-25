package rwb

import "base:runtime"
import "core:fmt"
import "core:io"
import os "core:os/os2"

//Logic for loading and utilising TTF fonts.

load_font :: proc(filepath: string) {
	font_data: []u8
	file_error: os.Error

	if os.exists(filepath) {
		font_data, file_error = os.read_entire_file_from_path(filepath, allocator = frame_alloc)

		if file_error == os.ERROR_NONE {
			fmt.println("Font loaded,", len(font_data), "bytes.")
		} else {
			fmt.println("Error loading font:", file_error)
		}
	} else {
		fmt.println("File doesn't exist")
	}

	scalar_type := font_data[0:4]
	num_tables := font_data[4:6]
	search_range := font_data[6:8]
	entry_selector := font_data[8:10]
	range_shifter := font_data[10:12]
	tag := font_data[12:16]
	check_sum := font_data[16:20]
	offset := font_data[20:24]
	length := font_data[24:28]

	tag_2 := font_data[28:32]
	check_sum_2 := font_data[32:36]
	offset_2 := font_data[36:40]
	length_2 := font_data[40:44]

	tag_3 := font_data[44:48]

	fmt.println("Number of tables:", u16(num_tables[0] << 8 + num_tables[1]))
	fmt.println("Search range", u16(search_range[0] << 8 + search_range[1]))
	fmt.printfln("tag: %v%v%v%v", rune(tag[0]), rune(tag[1]), rune(tag[2]), rune(tag[3]))
	fmt.println("Offset:", u32(offset[0] << 24 + offset[1] << 16 + offset[2] << 8 + offset[3]))
	fmt.println("Length:", u32(length[0] << 24 + length[1] << 16 + length[2] << 8 + length[3]))
	fmt.printfln("tag: %v%v%v%v", rune(tag_2[0]), rune(tag_2[1]), rune(tag_2[2]), rune(tag_2[3]))
	fmt.println(
		"Offset:",
		u32(offset_2[0] << 24 + offset_2[1] << 16 + offset_2[2] << 8 + offset_2[3]),
	)
	fmt.println(
		"Length:",
		u32(length_2[0] << 24 + length_2[1] << 16 + length_2[2] << 8 + length_2[3]),
	)
	fmt.printfln("tag: %v%v%v%v", rune(tag_3[0]), rune(tag_3[1]), rune(tag_3[2]), rune(tag_3[3]))
}
