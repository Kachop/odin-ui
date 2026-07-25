package font
import renderer "../renderer/"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"

//All logic for triangulating glyfs.
//Will transform contours of points into triangulated point clouds ready for rendering.
//Will happen when font is loaded, meaning no calculation is needed each time a glyf is drawn.

//TODO:Make the triangles some sort of tree node system. Append triangle can automatically keep track of neighbours that way.

Vec2 :: [2]f32

Vertices :: [3]renderer.Point
Indices :: [3]u32
Adjacencies :: [3]u32
Edge :: [2]renderer.Point

Triangle :: struct {
	vertices:    Vertices,
	indices:     Indices,
	adjacencies: Adjacencies,
	is_bad:      bool,
}

Triangulation :: struct {
	vertices: [dynamic]Vertices,
	indices:  [dynamic]Indices,
	is_bad:   [dynamic]bool,
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

edge_from_points :: proc(p0, p1: renderer.Point) -> (Edge, bool) #optional_ok {
	if (p0.x + p0.y) <= (p1.x + p1.y) {
		return Edge{p0, p1}, false
	}
	return Edge{p1, p0}, true
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

point_in_circumcircle :: proc(vertices: Vertices, point: renderer.Point) -> bool {
	//Tests if a point is inside the circumcircle of a triangle.
	/*
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
	}*/
	mat := matrix[4, 4]f32{
		vertices[0].x, vertices[0].y, (vertices[0].x * vertices[0].x) + (vertices[0].y * vertices[0].y), 1, 
		vertices[1].x, vertices[1].y, (vertices[1].x * vertices[1].x) + (vertices[1].y * vertices[1].y), 1, 
		vertices[2].x, vertices[2].y, (vertices[2].x * vertices[2].x) + (vertices[2].y * vertices[2].y), 1, 
		point.x, point.y, (point.x * point.x) + (point.y * point.y), 1, 
	}
	det := linalg.determinant(mat)
	if det > 0 {
		return true
	}
	return false
}

is_triangle_counter_clockwise :: proc(vertices: Vertices) -> bool {
	z :=
		((vertices[1].x - vertices[0].x) * (vertices[2].y - vertices[0].y)) -
		((vertices[1].y - vertices[0].y) * (vertices[2].x - vertices[0].x))
	if z > 0 {
		return true
	}
	return false
}

make_new_triangles :: proc(
	edges: [dynamic]Edge,
	edge_indices: [dynamic][2]u32,
	point: renderer.Point,
	point_index: u32,
	triangulation: ^Triangulation,
) {
	//Make X new triangles around the point. Connect all adjacencies
	vertices: Vertices
	indices: Indices
	fmt.println("Triangle edges:", edges)
	for edge, idx in edges {
		if is_triangle_counter_clockwise(Vertices{point, edge[0], edge[1]}) {
			vertices = Vertices{point, edge[0], edge[1]}
			indices = Indices{point_index, edge_indices[idx][0], edge_indices[idx][1]}
		} else {
			vertices = Vertices{point, edge[1], edge[0]}
			indices = Indices{point_index, edge_indices[idx][1], edge_indices[idx][0]}
		}

		fmt.println("Making new triangle with vertices:", vertices)

		append(&triangulation.vertices, vertices)
		append(&triangulation.indices, indices)
		append(&triangulation.is_bad, false)
	}
}

triangulate :: proc(glyf: ^Glyf_Data) {
	triangulation := Triangulation {
		vertices = make([dynamic]Vertices, allocator = context.temp_allocator),
		indices  = make([dynamic]Indices, allocator = context.temp_allocator),
		is_bad   = make([dynamic]bool, allocator = context.temp_allocator),
	}

	defer {
		delete(triangulation.vertices)
		delete(triangulation.indices)
		delete(triangulation.is_bad)
	}

	glyf_point_cloud := glyf.bezier_curve_points

	scaled_point_cloud := scale_point_cloud(glyf_point_cloud)

	base_triangle_vertices := Vertices{{10, -10}, {0, 10}, {-10, -10}}
	base_triangle_indices := Indices{0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF}

	append(&triangulation.vertices, base_triangle_vertices)
	append(&triangulation.indices, base_triangle_indices)
	append(&triangulation.is_bad, false)

	polygon_edges := make([dynamic]Edge, allocator = context.temp_allocator)
	polygon_indices := make([dynamic][2]u32, allocator = context.temp_allocator)

	//Add all of the edges of all of the bad triangles to a running tally
	//Any edges with a count of 1 are not shared, any edges with a count of 2 are.
	edge_counter := make(map[Edge]u32, allocator = context.temp_allocator)
	defer delete(edge_counter)

	defer delete(polygon_edges)
	defer delete(polygon_indices)

	for point, i in scaled_point_cloud {
		fmt.println("\rAdding point:", i, "/", len(scaled_point_cloud), point)
		clear(&polygon_edges)
		clear(&polygon_indices)
		clear(&edge_counter)

		for triangle_vertices, idx in triangulation.vertices {
			if point_in_circumcircle(triangle_vertices, point) {
				triangulation.is_bad[idx] = true

				//fmt.println("Vertices:", vertices)
				#unroll for j in 0 ..< 3 {
					//fmt.println("Edge:", j)
					edge := edge_from_points(
						triangle_vertices[j],
						triangle_vertices[j + 1 if (j + 1 < 3) else j + 1 - 3],
					)
					edge_counter[edge] += 1
					//fmt.println("Edge count:", edge_counter[edge])
					assert(edge_counter[edge] <= 2)
				}
			} else {
				triangulation.is_bad[idx] = false
			}
		}
		//fmt.println("Done checking circumcircle")

		//fmt.println(edge_counter)

		for bad_triangle, idx in triangulation.is_bad {
			if !bad_triangle {
				continue
			}
			vertices := triangulation.vertices[idx]
			indices := triangulation.indices[idx]
			#unroll for j in 0 ..< 3 {
				edge, swapped := edge_from_points(
					vertices[j],
					vertices[j + 1 if (j + 1 < 3) else j + 1 - 3],
				)
				edge_indices: [2]u32
				if swapped {
					edge_indices = [2]u32{indices[j + 1 if (j + 1 < 3) else j + 1 - 3], indices[j]}
				} else {
					edge_indices = [2]u32{indices[j], indices[j + 1 if (j + 1 < 3) else j + 1 - 3]}
				}
				if edge_counter[edge] == 1 {
					append(&polygon_edges, edge)
					append(&polygon_indices, edge_indices)
				}
			}
		}
		//fmt.println("Done creating polygon", len(polygon_edges))

		#reverse for bad_triangle, idx in triangulation.is_bad {
			if !bad_triangle {
				continue
			}
			ordered_remove(&triangulation.vertices, u32(idx))
			ordered_remove(&triangulation.indices, u32(idx))
			ordered_remove(&triangulation.is_bad, u32(idx))
		}

		//fmt.println("Done removing bad triangles")
		//fmt.println("Polygon edges:", polygon_edges)

		make_new_triangles(polygon_edges, polygon_indices, point, u32(i), &triangulation)
		//fmt.println("Done creating new triangles")
	}
	//fmt.print("\n")

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
