package font
import renderer "../renderer/"
import "core:fmt"
import "core:math"
import "core:slice"

//All logic for triangulating glyfs.
//Will transform contours of points into triangulated point clouds ready for rendering.
//Will happen when font is loaded, meaning no calculation is needed each time a glyf is drawn.

//TODO:Make the triangles some sort of tree node system. Append triangle can automatically keep track of neighbours that way.

idx :: u32

Vec2 :: [2]f32

Triangle :: struct {
	child_first: ^Triangle,
	child_last:  ^Triangle,
	adjacencies: [3]^Triangle, //0-adjacent to side v0/v1, 1-adjacent to side v1/v2, 3-adjacent to side v2/0
	vertices:    [3]renderer.Point,
	indices:     [3]u32, //Index of glyf point for rendering.
	traversed:   bool,
}

triangle :: proc(
	child_first: ^Triangle = nil,
	child_last: ^Triangle = nil,
	adjacencies: [3]^Triangle = {},
	vertices: [3]renderer.Point = {},
	indicies: [3]u32 = {},
) -> Triangle {
	return Triangle {
		child_first = child_first,
		child_last = child_last,
		adjacencies = adjacencies,
		vertices = vertices,
		indices = indicies,
	}
}

normalise_point_0_1 :: proc(
	point: renderer.Point,
	min_x, max_x, min_y, max_y: f32,
) -> renderer.Point {
	return renderer.Point{(point.x - min_x) / (max_x - min_x), (point.y - min_y) / (max_y - min_y)}
}

distance :: proc(p1, p2: renderer.Point) -> f32 {
	return math.sqrt(math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2))
}

vec2_from_points :: proc(p1, p2: renderer.Point) -> Vec2 {
	return Vec2{p2.x - p1.x, p2.y - p1.y}
}

dot :: proc(v1, v2: Vec2) -> f32 {
	return (v1.x * v2.x) + (v1.y * v2.y)
}

cross :: proc(v1, v2: Vec2) -> f32 {
	return (v1.x * v2.y) - (v1.y * v2.x)
}

normal :: proc(vec: Vec2) -> Vec2 {
	return Vec2{vec.y, -vec.x}
}

length :: proc(vec: Vec2) -> f32 {
	return math.sqrt(math.pow(vec.x, 2) + math.pow(vec.y, 2))
}

get_unit_vec :: proc(vec: Vec2) -> Vec2 {
	vec_len := length(vec)
	return Vec2{vec.x / vec_len, vec.y / vec_len}
}

midpoint :: proc(vec: Vec2) -> renderer.Point {
	return {vec.x / 2, vec.y / 2}
}

calculate_triangle_center :: proc(triangle: ^Triangle) -> Vec2 {
	x_component := (triangle.vertices[0].x + triangle.vertices[1].x + triangle.vertices[2].x) / 3
	y_component := (triangle.vertices[0].y + triangle.vertices[1].y + triangle.vertices[2].y) / 3
	return Vec2{x_component, y_component}
}

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

point_in_triangle :: proc(point: renderer.Point, triangle: ^Triangle) -> bool {
	//Uses barycentric method to figure out if a point is within a triangle.
	v0 := vec2_from_points(triangle.vertices[2], triangle.vertices[0]) //C-A
	v1 := vec2_from_points(triangle.vertices[1], triangle.vertices[0]) //B-A
	v2 := vec2_from_points(point, triangle.vertices[0])

	d_00 := dot(v0, v0)
	d_01 := dot(v0, v1)
	d_11 := dot(v1, v1)
	d_20 := dot(v2, v0)
	d_21 := dot(v2, v1)

	denom := (d_00 * d_11) - (d_01 * d_01)
	u := ((d_11 * d_20) - (d_01 * d_21)) / denom
	v := ((d_00 * d_21) - (d_01 * d_20)) / denom

	if u >= 0 && v >= 0 && u + v <= 1 {
		return true
	}
	return false
	/*
	if triangle.adjacencies[0] == nil &&
	   triangle.adjacencies[1] == nil &&
	   triangle.adjacencies[2] == nil {
		return true
	}
	return false
	*/
}

find_parent_edge :: proc(new_triangle, adjacent_triangle: ^Triangle) -> u32 {
	//Finds the parent edge which is closest to the new point being inserted
	//Finds the first non point vertex that matches between the adjacent triangle and the new one.
	//First matching point matches the matching edge
	for i in 0 ..< 3 {
		if adjacent_triangle.vertices[i] == new_triangle.vertices[2] {
			fmt.println("Found parent edge!!!", i)
			return u32(i)
		}
	}
	return 0
}

find_closest_edge :: proc(triangle: ^Triangle, point: renderer.Point) -> u32 {
	//point_vec := vec2_from_points(calculate_triangle_center(triangle), point)
	//point_unit_vec := get_unit_vec(point_vec)

	lowest_distance: f32 = 1000000 //0-1 how much the vector points towards the POI.
	highest_alignment: f32 = 0
	adjacent_side: u32

	for i in 0 ..< 3 {
		//Check each vertex
		vertex := triangle.vertices[i]
		next_vertex := triangle.vertices[i + 1 if (i + 1 < 3) else i + 1 - 3]

		vec_to_point := vec2_from_points(vertex, point)

		vec_egde := vec2_from_points(vertex, next_vertex)

		edge_dot := dot(get_unit_vec(vec_to_point), get_unit_vec(vec_egde))

		fmt.println("Edge dot:", edge_dot)

		face_vec := vec2_from_points(
			triangle.vertices[i],
			triangle.vertices[i + 1 if (i + 1 < 3) else i + 1 - 3],
		)

		face_normal_vec := normal(vec_egde)

		face_unit_vec := get_unit_vec(face_normal_vec)

		point_vec := vec2_from_points(midpoint(vec_egde), point)
		point_unit_vec := get_unit_vec(point_vec)

		face_alignment := dot(point_unit_vec, face_unit_vec)
		fmt.println("alignment:", face_alignment)

		t := math.clamp(edge_dot / dot(vec_egde, vec_egde), 0, 1)
		Q := vertex + ((next_vertex - vertex) * t)
		d := distance(point, Q)
		fmt.println("i:", i, "d:", d)
		if abs(d - lowest_distance) < 0.1 {
			if face_alignment > highest_alignment {
				lowest_distance = d
				highest_alignment = face_alignment
				adjacent_side = u32(i)
			}
		}
	}
	/*
	for i in 0 ..< 3 {	

		if face_alignment > alignment {
			alignment = face_alignment
			adjacent_side = u32(i)
		}
	}
	*/

	fmt.println("Selected:", adjacent_side)
	return adjacent_side
}

find_containing_triangle :: proc(
	starting_triangle: ^Triangle,
	point: renderer.Point,
) -> ^Triangle {
	//Traverse from the starting triangle through the triangles to find the one which contains the point

	fmt.println("Finding containing triangle for:", point)
	current_triangle := starting_triangle

	fmt.println(starting_triangle)

	for {
		//Search for triangle
		fmt.println("Triangle:", current_triangle)
		fmt.println("Point:", point)
		if point_in_triangle(point, current_triangle) {
			fmt.println("Containing triangle found!!!!!!!!!!!!!!!!")
			return current_triangle
		}

		adjacent_side := find_closest_edge(current_triangle, point)
		new_triangle := current_triangle.adjacencies[adjacent_side]
		current_triangle = new_triangle

	}

	return {}
}

make_new_triangles :: proc(parent: ^Triangle, point: renderer.Point, index: u32) {
	//Make three new triangles using the parent triangle and the point.
	//Take care of adjacencies and deletion
	for i in 0 ..< 3 {
		new_triangle := new(Triangle, allocator = context.temp_allocator)

		new_triangle.vertices = {
			point,
			parent.vertices[i],
			parent.vertices[i + 1 if (i + 1 < 3) else i + 1 - 3],
		}

		new_triangle.indices = {
			index,
			parent.indices[i],
			parent.indices[i + 1 if (i + 1 < 3) else i + 1 - 3],
		}

		if parent.child_first == nil {
			parent.child_first = new_triangle
			parent.child_last = new_triangle
		} else {
			parent.child_last.adjacencies[2] = new_triangle
			new_triangle.adjacencies[0] = parent.child_last
			parent.child_last = new_triangle
		}

		if i == 2 {
			parent.child_first.adjacencies[0] = parent.child_last
			parent.child_last.adjacencies[2] = parent.child_first
		}

		new_triangle.adjacencies[1] = parent.adjacencies[i] //1 adjacent triangle is inherited from the parent. 2 are then from the connections of the other two inner triangles.
		if parent.adjacencies[i] != nil {
			parent_adjacency := find_parent_edge(new_triangle, parent.adjacencies[i])
			parent.adjacencies[i].adjacencies[parent_adjacency] = new_triangle //Set adjacency of parent adjacencies so that parent triangle can be deleted without leaving nil pointers.
		}
	}
}

swap_edge :: proc(t1, t2: ^Triangle) {
	//Swap the edge between the two triangles. t1 is stack triangle, t2 contains the point.

	//Should have 4 vertices. Two shared.
	//Shared vertices will be both non P vertices in t2.
	//P will be part of the new edge.
	vertices := [4]renderer.Point{}
	indices := [4]u32{}

	vertices[0] = t2.vertices[0] //Point P
	indices[0] = t2.indices[0] //Point P

	adjacent_face := find_closest_edge(t1, vertices[0])

	vertices[1] =
		t1.vertices[adjacent_face + 1 if (adjacent_face + 1 < 3) else adjacent_face + 1 - 3] //First shared vertex
	indices[1] =
		t1.indices[adjacent_face + 1 if (adjacent_face + 1 < 3) else adjacent_face + 1 - 3] //First shared index
	vertices[2] = t1.vertices[adjacent_face] //Second shared vertex
	indices[2] = t1.indices[adjacent_face] //Second shared index

	vertices[3] =
		t1.vertices[adjacent_face + 2 if (adjacent_face + 2 < 3) else adjacent_face + 2 - 3] //Free point on triangle without point P
	indices[3] =
		t1.indices[adjacent_face + 2 if (adjacent_face + 2 < 3) else adjacent_face + 2 - 3] //Free point index on triangle without point P

	//t1 = v2, v1, v3
	//t2 = v0, v1, v2

	//t1 = v0, v3, v2
	//t2 = v0, v1, v3

	t1.vertices[0] = vertices[0];t1.indices[0] = indices[0]
	t1.vertices[1] = vertices[3];t1.indices[1] = indices[3]
	t1.vertices[2] = vertices[2];t1.indices[2] = indices[2]

	t2.vertices[0] = vertices[0];t2.indices[0] = indices[0]
	t2.vertices[1] = vertices[1];t2.indices[1] = indices[1]
	t2.vertices[2] = vertices[3];t2.indices[2] = indices[3]

	t1_adjacencies := t1.adjacencies
	t2_adjacencies := t2.adjacencies

	t1.adjacencies[0] = t2
	t1.adjacencies[1] =
		t2_adjacencies[adjacent_face + 2 if (adjacent_face + 2 < 3) else adjacent_face + 2 - 3]
	t2.adjacencies[0] = t1_adjacencies[0]
	t2.adjacencies[1] =
		t2_adjacencies[adjacent_face + 1 if (adjacent_face + 1 < 3) else adjacent_face + 1 - 3]
	t2.adjacencies[2] = t1
}

point_in_circumcircle :: proc(triangle: ^Triangle, point: renderer.Point) -> bool {
	//Tests if a point is inside the circumcircle of a triangle.
	vec_13 := vec2_from_points(triangle.vertices[0], triangle.vertices[2])
	vec_23 := vec2_from_points(triangle.vertices[1], triangle.vertices[2])
	vec_1p := vec2_from_points(triangle.vertices[0], point)
	vec_2p := vec2_from_points(triangle.vertices[1], point)

	cos_A := dot(vec_13, vec_23)
	cos_B := dot(vec_1p, vec_2p)

	if cos_A >= 0 && cos_B >= 0 {
		return false
	} else if cos_A < 0 && cos_B < 0 {
		return true
	}

	sin_A := cross(vec_13, vec_23)
	sin_B := cross(vec_2p, vec_1p)
	sin_AB := (sin_A * cos_B) + (sin_B * cos_A)

	if sin_AB < 0 {
		return true
	} else {
		return false
	}
}

triangulate :: proc(glyf: ^Glyf_Data) {
	//Triangulate the glyf based on the glyf coordinates.
	glyf_point_cloud := glyf.bezier_curve_points

	fmt.println("Doing triangulation...", len(glyf_point_cloud))

	scaled_point_cloud := scale_point_cloud(glyf_point_cloud)

	parent_triangle: ^Triangle

	base_triangle := triangle(
		vertices = {{100, -100}, {0, 100}, {-100, -100}},
		indicies = {0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF},
	)
	current_triangle := &base_triangle //Reference to whatever triangle we're currently inside of.

	adjacent_stack := make([dynamic]^Triangle, allocator = context.temp_allocator)
	defer delete(adjacent_stack)

	for point, i in scaled_point_cloud {
		fmt.println("Adding point", i)
		clear(&adjacent_stack)
		containing_triangle := find_containing_triangle(current_triangle, point)
		for i in 0 ..< 3 {
			if containing_triangle.adjacencies[i] != nil {
				append(&adjacent_stack, containing_triangle.adjacencies[i])
			}
		}

		fmt.println("Added to stack", len(adjacent_stack))

		make_new_triangles(containing_triangle, point, u32(i))

		fmt.println("Made new triangles")

		for len(adjacent_stack) > 0 {
			stack_triangle := pop(&adjacent_stack)

			if point_in_circumcircle(stack_triangle, point) {
				//Wrong diagonal between stack triangle and the stack triangle adjacency which points towards point.
				stack_triangle_adjacency := find_closest_edge(stack_triangle, point)
				pair_triangle := stack_triangle.adjacencies[stack_triangle_adjacency]

				//swap_edge(stack_triangle, pair_triangle)
				//append(&adjacent_stack, stack_triangle.adjacencies[1])
				//append(&adjacent_stack, pair_triangle.adjacencies[1])
			}
		}
		current_triangle = containing_triangle.child_last
	}

	fmt.println("Scaled point cloud")

	indices := make([dynamic]u32, allocator = glyf.allocator)
	prev_triangle := current_triangle
	fail_count: u8

	for {
		if !current_triangle.traversed { 	//Only add indices for each triangle once.
			for index in current_triangle.indices {
				if index != 0xFFFFFFFF {
					append(&indices, index)
				}
			}
			current_triangle.traversed = true
		}
		fail_count = 0
		for adjacent_triangle in current_triangle.adjacencies {
			if adjacent_triangle != nil {
				if !adjacent_triangle.traversed {
					current_triangle = adjacent_triangle
				} else {
					fail_count += 1
				}
			} else {
				fail_count += 1
			}
		}
		if fail_count >= 3 {
			break
		}
	}
	glyf.indices = indices[:]
}
