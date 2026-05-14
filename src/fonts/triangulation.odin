package font
import renderer "../renderer/"
import "core:slice"

//All logic for triangulating glyfs.
//Will transform contours of points into triangulated point clouds ready for rendering.
//Will happen when font is loaded, meaning no calculation is needed each time a glyf is drawn.

idx :: u32

Triangle :: struct {
	vertices: [3]idx,
}

normalise_point_0_1 :: proc(
	point: renderer.Point,
	min_x, max_x, min_y, max_y: f32,
) -> renderer.Point {
	return renderer.Point{(point.x - min_x) / (max_x - min_x), (point.y - min_y) / (max_y - min_y)}
}

dot :: proc() {} 	//Dot product for vec2

cross :: proc() {} 	//Cross product for vec2

scale_point_cloud :: proc(points: []renderer.Point) -> []renderer.Point {
	//Scales the point cloud between (0, 0) and (1, 1)
	//Preserves relative distances for later.
	//1. Find the larger axis.
	//2. Set the min value to 0 and the max value to 1, scale all other points.
	//3. Scale all points on other axis between 0 and 1.

	scaled_points := make([]renderer.Point, len(points), allocator = font_alloc)

	x_min, x_max: f32 = 1000000, 0
	y_min, y_max: f32 = 1000000, 0

	for point, i in points {
		if point.x < x_min {
			x_min = point.x
		}
		if point.x > x_max {
			x_max = point.x
		}
		if point.y < y_min {
			y_min = point.y
		}
		if point.y > y_max {
			y_max = point.y
		}
	}

	if (x_max - x_min) > (y_max - y_min) {
		//x axis is longer, scale from that.
		//Normalise points
		//Normalise other axis points using same ratios
		axis_ratio := (x_max - x_min) / (y_max - y_min)
		axis_diff := (y_max - y_min) * axis_ratio / 2
		for point, i in points {
			scaled_points[i] = normalise_point_0_1(
				point,
				x_min,
				x_max,
				y_min - axis_diff,
				y_max + axis_diff,
			)
		}
	} else {
		//y axis is longer, scale from that.
		axis_ratio := (y_max - y_min) / (x_max - x_min)
		axis_diff := (x_max - x_min) * axis_ratio / 2
		for point, i in points {
			scaled_points[i] = normalise_point_0_1(
				point,
				x_min - axis_diff,
				x_max + axis_diff,
				y_min,
				y_max,
			)
		}
	}
	return scaled_points
}
