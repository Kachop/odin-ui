#version 330 core
layout (location = 0) in vec2 aPos;

uniform mat4 projection_matrix;

void main()
{
	gl_Position = projection_matrix * vec4(aPos.x, aPos.y, 0.0, 1.0);
}
