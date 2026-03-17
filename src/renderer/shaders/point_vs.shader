#version 330 core
layout (location = 0) in vec2 aPos;

uniform float point_size;

void main()
{
	gl_PointSize = point_size;
	gl_Position = vec4(aPos.x, -aPos.y, 0.0, 1.0);
}
