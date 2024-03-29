#version 450 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 uv;

layout (location = 0) out vec2 out_texCoord;

void main()
{
	out_texCoord = uv;
	gl_Position = vec4(position, 1.0);
}