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

Vertices :: [3]renderer.Point
Indices :: [3]u32
Adjacencies :: [3]u32

Triangulation :: struct {
	vertices: [dynamic]Vertices,
	indices:  [dynamic]Indices,
}
/*
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
*/
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
/*
calculate_triangle_center :: proc(triangle: ^Triangle) -> renderer.Point {
	x_component := (triangle.vertices[0].x + triangle.vertices[1].x + triangle.vertices[2].x) / 3
	y_component := (triangle.vertices[0].y + triangle.vertices[1].y + triangle.vertices[2].y) / 3
	return renderer.Point{x_component, y_component}
}
*/
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
/*
point_in_triangle :: proc(point: renderer.Point, vertices: Vertices) -> bool {
	//Uses barycentric method to figure out if a point is within a triangle.
	v0 := vec2_from_points(vertices[2], vertices[0]) //C-A
	v1 := vec2_from_points(vertices[1], vertices[0]) //B-A
	v2 := vec2_from_points(point, vertices[0])

	d_00 := dot(v0, v0)
	d_01 := dot(v0, v1)
	d_11 := dot(v1, v1)
	d_20 := dot(v2, v0)
	d_21 := dot(v2, v1)

	denom := (d_00 * d_11) - (d_01 * d_01)
	u := ((d_11 * d_20) - (d_01 * d_21)) / denom
	v := ((d_00 * d_21) - (d_01 * d_20)) / denom

	if u >= 0 && u <= 1 && v >= 0 && v <= 1 && u + v < 1 {
		return true
	}
	return false
}

find_matching_edge :: proc(t1, t2: u32, triangulation: ^Triangulation) -> u32 {
	//Finds the matching edge between two triangles.
	//Finds the first non point vertex that matches between the adjacent triangle and the new one.
	//First matching point matches the matching edge
	//Returns the matching edge from the perspective of t1
	for i in 0 ..< 3 {
		if triangulation.vertices[t1][i] == triangulation.vertices[t2][2] {
			return u32(i)
		}
	}
	return 0
}
/*
find_closest_edge :: proc(triangle: ^Triangle, point: renderer.Point) -> u32 {
	//fmt.println("Finding closest edge for triangle:", triangle, "\npoint:", point)
	//point_vec := vec2_from_points(calculate_triangle_center(triangle), point)
	//point_unit_vec := get_unit_vec(point_vec)

	lowest_distance: f32 = 1000000 //0-1 how much the vector points towards the POI.
	highest_alignment: f32 = 0
	adjacent_side: u32
	/*
	for i in 0 ..< 3 {
		if triangle.adjacencies[i] != nil {
			triangle_to_check := triangle.adjacencies[i]

			triangle_center := calculate_triangle_center(triangle_to_check)
			dist := distance(triangle_center, point)
			if dist < lowest_distance {
				lowest_distance = dist
				adjacent_side = u32(i)
			}
		}
	}
*/
	for i in 0 ..< 3 {
		//Check each vertex
		vertex := triangle.vertices[i]
		next_vertex := triangle.vertices[i + 1 if (i + 1 < 3) else i + 1 - 3]

		edge_vec := vec2_from_points(vertex, next_vertex)

		face_normal_vec := normal(edge_vec)

		face_unit_vec := get_unit_vec(face_normal_vec)
		//fmt.println("Face unit vec:", face_unit_vec)

		midpoint := (vertex + next_vertex) / 2

		//NOTE: Point unit vec values seem messed up. X and Y values look wrong sign sometimes.
		point_vec := vec2_from_points(midpoint, point)
		point_unit_vec := get_unit_vec(point_vec)
		//fmt.println("Point unit vec:", point_unit_vec)

		face_alignment := dot(point_unit_vec, face_unit_vec)
		//fmt.println("alignment:", face_alignment)

		edge_dot := dot(edge_vec, vec2_from_points(vertex, point))

		t := math.clamp(edge_dot / dot(edge_vec, edge_vec), 0, 1)
		//fmt.println("t:", t)
		Q := vertex + (edge_vec * t)
		d := distance(point, Q)
		//fmt.println("i:", i, "d:", d)
		if d < lowest_distance {
			lowest_distance = d
			adjacent_side = u32(i)
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

	//fmt.println("Selected:", adjacent_side)
	return adjacent_side
}
*/
find_containing_triangle :: proc(point: renderer.Point, triangulation: Triangulation) -> u32 {
	//Traverse from the starting triangle through the triangles to find the one which contains the point

	//NOTE:Maybe just loop over all triangles, slightly slower but saves faf with current algorythm.

	//fmt.println("Finding containing triangle for:", point)

	index_destroyed: bool
	for index, i in triangulation.index {
		for destroyed_index in triangulation.destroyed_list {
			if index == destroyed_index {
				index_destroyed = true
				break
			}
		}

		if !index_destroyed {
			if point_in_triangle(point, triangulation.vertices[i]) {
				//fmt.println("Containing triangule found!")
				return index
			}
		}
		index_destroyed = false
	}
	//fmt.println("Could not find containing triangle")
	return {}
}

make_new_triangles :: proc(
	parent: u32,
	point: renderer.Point,
	triangle_index: u32,
	triangulation: ^Triangulation,
) {
	//Make three new triangles using the parent triangle and the point.
	//Take care of adjacencies and deletion
	for i in 0 ..< 3 {
		index := u32(len(triangulation.index))

		new_vertices := Vertices {
			point,
			triangulation.vertices[parent][i],
			triangulation.vertices[parent][i + 1 if (i + 1 < 3) else i + 1 - 3],
		}

		new_indices := Indices {
			triangle_index,
			triangulation.indices[parent][i],
			triangulation.indices[parent][i + 1 if (i + 1 < 3) else i + 1 - 3],
		}

		append(&triangulation.index, index)
		append(&triangulation.vertices, new_vertices)
		append(&triangulation.indices, new_indices)

		new_adjacencies := Adjacencies{}
		append(&triangulation.adjacencies, new_adjacencies)

		if i >= 1 {
			triangulation.adjacencies[len(triangulation.adjacencies) - 2][2] = index
			triangulation.adjacencies[len(triangulation.adjacencies) - 1][0] =
				triangulation.index[len(triangulation.index) - 2]
		}

		if i == 2 {
			triangulation.adjacencies[len(triangulation.adjacencies) - 3][0] = index
			triangulation.adjacencies[len(triangulation.adjacencies) - 1][2] =
				triangulation.index[len(triangulation.index) - 3]
		}

		triangulation.adjacencies[len(triangulation.adjacencies) - 1] =
			triangulation.adjacencies[parent][1] //1 adjacent triangle is inherited from the parent. 2 are then from the connections of the other two inner triangles.

		if triangulation.adjacencies[parent][i] != 0xFFFFFFFF {
			parent_adjacency := find_matching_edge(
				index,
				triangulation.adjacencies[parent][i],
				triangulation,
			)
			triangulation.adjacencies[triangulation.adjacencies[parent][i]][parent_adjacency] =
				index
		}
	}
}

is_convex :: proc(t1, t2: u32, triangulation: Triangulation) -> bool {
	t1_free_point: u32
	t2_free_point: u32

	match: bool
	t2_match_total: u32

	for t1_vertex, i in triangulation.vertices[t1] {
		for t2_vertex, j in triangulation.vertices[t2] {
			if t1_vertex == t2_vertex {
				match = true
				t2_match_total += u32(j)
			}
		}
		if !match {
			t1_free_point = u32(i)
		}
		match = false
	}

	if t2_match_total == 3 {
		t2_free_point = 0
	} else if t2_match_total == 2 {
		t2_free_point = 1
	} else if t2_match_total == 1 {
		t2_free_point = 2
	}

	t1_edge_1 := vec2_from_points(
		triangulation.vertices[t1][t1_free_point + 1 if (t1_free_point + 1 < 3) else t1_free_point + 1 - 3],
		triangulation.vertices[t1][t1_free_point],
	)
	t1_edge_2 := vec2_from_points(
		triangulation.vertices[t1][t1_free_point],
		triangulation.vertices[t1][t1_free_point + 2 if (t1_free_point + 2 < 3) else t1_free_point + 2 - 3],
	)

	t2_edge_1 := vec2_from_points(
		triangulation.vertices[t2][t2_free_point + 1 if (t2_free_point + 1 < 3) else t2_free_point + 1 - 3],
		triangulation.vertices[t2][t2_free_point],
	)
	t2_edge_2 := vec2_from_points(
		triangulation.vertices[t2][t2_free_point],
		triangulation.vertices[t2][t2_free_point + 2 if (t2_free_point + 2 < 3) else t2_free_point + 2 - 3],
	)

	cross_t1_1_t1_2 := cross(t1_edge_1, t1_edge_2)
	cross_t1_1_t2_2 := cross(t1_edge_1, t2_edge_2)
	cross_t2_1_t1_2 := cross(t2_edge_1, t1_edge_2)
	cross_t2_1_t2_2 := cross(t2_edge_1, t2_edge_2)

	return(
		(cross_t1_1_t1_2 > 0 &&
			cross_t1_1_t2_2 > 0 &&
			cross_t2_1_t1_2 > 0 &&
			cross_t2_1_t2_2 > 0) ||
		(cross_t1_1_t1_2 < 0 &&
				cross_t1_1_t2_2 < 0 &&
				cross_t2_1_t1_2 < 0 &&
				cross_t2_1_t2_2 < 0) \
	)
}

swap_edge :: proc(t1, t2: u32, triangulation: ^Triangulation) {
	//Swap the edge between the two triangles. t1 is stack triangle, t2 contains the point.

	//Should have 4 vertices. Two shared.
	//Shared vertices will be both non P vertices in t2.
	//P will be part of the new edge.
	//if !is_convex(t1, t2, triangulation^) {
	//fmt.println("Could not swap, not convex")
	//	return
	//}
	vertices := [4]renderer.Point{}
	indices := [4]u32{}

	vertices[0] = triangulation.vertices[t2][0] //Point P
	indices[0] = triangulation.indices[t2][0] //Point P

	vertices[1] = triangulation.vertices[t2][1] //First shared vertex
	indices[1] = triangulation.indices[t2][1] //First shared index
	vertices[2] = triangulation.vertices[t2][2] //Second shared vertex
	indices[2] = triangulation.indices[t2][2] //Second shared index

	t1_free_vertex: u32

	for vertex, i in triangulation.vertices[t1] {
		if vertex != vertices[1] && vertex != vertices[2] {
			t1_free_vertex = u32(i)
		}
	}

	vertices[3] = triangulation.vertices[t1][t1_free_vertex] //Free point on triangle without point P
	indices[3] = triangulation.indices[t1][t1_free_vertex] //Free point index on triangle without point P

	//t1 = v2, v1, v3
	//t2 = v0, v1, v2

	//t1 = v0, v3, v2
	//t2 = v0, v1, v3

	triangulation.vertices[t1][0] = vertices[0];triangulation.indices[t1][0] = indices[0]
	triangulation.vertices[t1][1] = vertices[3];triangulation.indices[t1][1] = indices[3]
	triangulation.vertices[t1][2] = vertices[2];triangulation.indices[t1][2] = indices[2]

	triangulation.vertices[t2][0] = vertices[0];triangulation.indices[t2][0] = indices[0]
	triangulation.vertices[t2][1] = vertices[1];triangulation.indices[t2][1] = indices[1]
	triangulation.vertices[t2][2] = vertices[3];triangulation.indices[t2][2] = indices[3]

	t1_adjacencies := triangulation.adjacencies[t1]
	t2_adjacencies := triangulation.adjacencies[t2]

	triangulation.adjacencies[t1][0] = t2
	triangulation.adjacencies[t1][1] = t2_adjacencies[t1_free_vertex]
	triangulation.adjacencies[t1][2] = t2_adjacencies[2]
	triangulation.adjacencies[t2][1] =
		t2_adjacencies[t1_free_vertex + 2 if (t1_free_vertex + 2 < 3) else t1_free_vertex + 2 - 3]
	triangulation.adjacencies[t2][2] = t1

	for i in 0 ..< 2 {
		if triangulation.adjacencies[t1][i + 1] != 0xFFFFFFFF {
			matching_edge := find_matching_edge(
				t1,
				triangulation.adjacencies[t1][i + 1],
				triangulation,
			)
			triangulation.adjacencies[triangulation.adjacencies[t1][i + 1]] = t1
		}

		if triangulation.adjacencies[t2][i] != 0xFFFFFFFF {
			matching_edge := find_matching_edge(
				t2,
				triangulation.adjacencies[t2][i],
				triangulation,
			)
			triangulation.adjacencies[triangulation.adjacencies[t2][i]] = t2
		}
	}

	triangulation.adjacencies[triangulation.adjacencies[t2][2]] = 0
}
*/
point_in_circumcircle :: proc(vertices: Vertices, point: renderer.Point) -> bool {
	//Tests if a point is inside the circumcircle of a triangle.
	vec_13 := vec2_from_points(vertices[0], vertices[2])
	vec_23 := vec2_from_points(vertices[1], vertices[2])
	vec_1p := vec2_from_points(vertices[0], point)
	vec_2p := vec2_from_points(vertices[1], point)

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

edge_in_triangle :: proc(vertices: Vertices, edge: Vec2) -> bool {
	match: int

	for point in vertices {
		if edge[0] == point {
			match += 1
		}
		if edge[1] == point {
			match += 1
		}
	}

	if match == 2 {
		return true
	}
	return false
}

edge_is_shared :: proc(
	bad_triangles: [dynamic]u32,
	edge: Vec2,
	triangulation: Triangulation,
	skip_triangle: u32,
) -> bool {
	for i in 0 ..< len(bad_triangles) {
		if u32(i) == skip_triangle {
			continue
		}
		vertices := triangulation.vertices[bad_triangles[i]]
		if edge_in_triangle(vertices, edge) {
			return true
		}
	}
	return false
}

make_new_triangle :: proc(
	edge: Vec2,
	edge_indices: [2]u32,
	point: renderer.Point,
	point_index: u32,
	triangulation: ^Triangulation,
) {
	//Makes a new point from the edge and the point.
	vertices := Vertices{point, edge[0], edge[1]}
	indices := Indices{point_index, edge_indices[0], edge_indices[1]}

	append(&triangulation.vertices, vertices)
	append(&triangulation.indices, indices)
}

triangulate :: proc(glyf: ^Glyf_Data) {
	//Triangulate the glyf based on the glyf coordinates.
	/*
	triangulation := Triangulation {
		index          = make([dynamic]u32, allocator = context.temp_allocator),
		vertices       = make([dynamic]Vertices, allocator = context.temp_allocator),
		indices        = make([dynamic]Indices, allocator = context.temp_allocator),
		adjacencies    = make([dynamic]Adjacencies, allocator = context.temp_allocator),
		destroyed_list = make([dynamic]u32, allocator = context.temp_allocator),
	}

	glyf_point_cloud := glyf.bezier_curve_points

	//fmt.println("Doing triangulation...", len(glyf_point_cloud))

	scaled_point_cloud := scale_point_cloud(glyf_point_cloud)

	base_triangle_vertices := Vertices{{50, -50}, {0, 50}, {-50, -50}}
	base_triangle_indices := Indices{0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF}
	base_triangle_adjacencies := Adjacencies{0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF}

	append(&triangulation.index, 0)
	append(&triangulation.vertices, base_triangle_vertices)
	append(&triangulation.indices, base_triangle_indices)
	append(&triangulation.adjacencies, base_triangle_adjacencies)

	adjacent_stack := make([dynamic]u32, allocator = context.temp_allocator)
	defer delete(adjacent_stack)

	for point, i in scaled_point_cloud {
		//fmt.println("Adding point", i)
		clear(&adjacent_stack)
		containing_index := find_containing_triangle(point, triangulation)
		for i in 0 ..< 3 {
			if triangulation.adjacencies[containing_index][i] != 0xFFFFFFFF {
				append(&adjacent_stack, triangulation.adjacencies[containing_index][i])
			}
		}

		//fmt.println("Added to stack", len(adjacent_stack))

		make_new_triangles(containing_index, point, u32(i), &triangulation)
		append(&triangulation.destroyed_list, containing_index)

		//fmt.println("Made new triangles")

		for len(adjacent_stack) > 0 {
			stack_triangle := pop(&adjacent_stack)
			//fmt.println("Popped stack triangle")

			if point_in_circumcircle(stack_triangle, point, triangulation) {
				//fmt.println("Checking if circumcircle")
				//Wrong diagonal between stack triangle and the stack triangle adjacency which points towards point.
				pair_triangle: u32
				for adjacent_triangle in triangulation.adjacencies[stack_triangle] {
					if adjacent_triangle != 0xFFFFFFFF {
						for vertex in triangulation.vertices[adjacent_triangle] {
							if vertex == point {
								pair_triangle = adjacent_triangle
							}
						}
					}
				}
				swap_edge(stack_triangle, pair_triangle, &triangulation)
				if triangulation.adjacencies[stack_triangle][1] != 0xFFFFFFFF {
					append(&adjacent_stack, triangulation.adjacencies[stack_triangle][1])
				}
				if triangulation.adjacencies[pair_triangle][1] != 0xFFFFFFFF {
					append(&adjacent_stack, triangulation.adjacencies[pair_triangle][1])
				}
			}
			//fmt.println("Not circumcircle")
		}
	}
	*/

	triangulation := Triangulation {
		vertices = make([dynamic]Vertices, allocator = context.temp_allocator),
		indices  = make([dynamic]Indices, allocator = context.temp_allocator),
	}

	defer {
		delete(triangulation.vertices)
		delete(triangulation.indices)
	}

	glyf_point_cloud := glyf.bezier_curve_points

	//fmt.println("Doing triangulation...", len(glyf_point_cloud))

	scaled_point_cloud := scale_point_cloud(glyf_point_cloud)

	base_triangle_vertices := Vertices{{10, -10}, {0, 10}, {-10, -10}}
	base_triangle_indices := Indices{0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF}

	append(&triangulation.vertices, base_triangle_vertices)
	append(&triangulation.indices, base_triangle_indices)

	bad_triangles := make([dynamic]u32, allocator = context.temp_allocator)
	polygon_edges := make([dynamic]Vec2, allocator = context.temp_allocator)
	polygon_indices := make([dynamic][2]u32, allocator = context.temp_allocator)

	defer delete(bad_triangles)
	defer delete(polygon_edges)
	defer delete(polygon_indices)

	for point, i in scaled_point_cloud {
		fmt.print("\rAdding point:", i, "/", len(scaled_point_cloud))
		clear(&bad_triangles)
		clear(&polygon_edges)
		clear(&polygon_indices)

		for triangle_vertices, idx in triangulation.vertices {
			if point_in_circumcircle(triangle_vertices, point) {
				append(&bad_triangles, u32(idx))
			}
		}

		for triangle_index, bad_triangle_index in bad_triangles {
			vertices := triangulation.vertices[triangle_index]
			indices := triangulation.indices[triangle_index]
			for i in 0 ..< 3 {
				edge := vec2_from_points(
					vertices[i],
					vertices[i + 1 if (i + 1 < 3) else i + 1 - 3],
				)
				edge_indices := [2]u32{indices[i], indices[i + 1 if (i + 1 < 3) else i + 1 - 3]}
				if !edge_is_shared(bad_triangles, edge, triangulation, u32(bad_triangle_index)) {
					append(&polygon_edges, edge)
					append(&polygon_indices, edge_indices)
				}
			}
		}

		triangles_removed: u32
		for bad_triangle in bad_triangles {
			ordered_remove(&triangulation.vertices, bad_triangle - triangles_removed)
			ordered_remove(&triangulation.indices, bad_triangle - triangles_removed)
			triangles_removed += 1
		}

		for polygon_index in 0 ..< len(polygon_edges) {
			make_new_triangle(
				polygon_edges[polygon_index],
				polygon_indices[polygon_index],
				point,
				u32(i),
				&triangulation,
			)
		}
	}
	fmt.print("\n")

	indices := make([dynamic]u32, allocator = glyf.allocator)

	//NOTE:Can have a list of all triangles in the glyf and loop over them for adding indices. Since indices link to specific points and the points will not change order. Doesn't matter what order the triangles are looped over.

	exclude_triangle: bool
	for triangle_indices, i in triangulation.indices {
		for index in triangle_indices {
			if index == 0xFFFFFFFF {
				exclude_triangle = true
			}
		}

		if !exclude_triangle {
			for index in triangle_indices {
				append(&indices, index)
			}
		}
		exclude_triangle = false
	}

	glyf.indices = indices[:]
	//fmt.println("Indices:", len(indices))
}
