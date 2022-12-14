#version 450 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec2 uv;
layout (location = 3) in vec3 normal;
layout (location = 4) in mat4 modelviewMatrix; // one modelview matrix per instance


uniform struct LightInfo {
	vec3 position;
	vec3 La;
	vec3 Ld;
	vec3 Ls;
} lights[2];


uniform struct MaterialInfo {
	vec3 Ka;
	vec3 Kd;
	vec3 Ks;
	float shininess;
} material;


uniform mat4 projectionMatrix;


layout (location = 0) out vec2 out_texCoord;
layout (location = 1) out vec3 out_frontColor;
layout (location = 2) out vec3 out_backColor;


vec3 phongModel(int index, vec3 p, vec3 n)
{
	// compute ambient light
	vec3 ambient = lights[index].La * material.Ka;

	// compute diffuse
	vec3 s = normalize( lights[index].position.xyz - p );
	float dotResult = max(dot(s, n), 0.0);

	vec3 diffuse = lights[index].Ld * material.Kd * dotResult;

	// compute specular
	vec3 specular = vec3(0.0);

	if(dotResult > 0.0)
	{
		vec3 v = normalize(-p.xyz);
		vec3 r = reflect(-s, n);

		specular = lights[index].Ls * material.Ks * pow( max( dot(r, v), 0.0), material.shininess);
	}

	return ambient + diffuse + specular;
}


void main()
{
	// getting the normal matrix transformation from modelview matrix transformation
	mat3 normalMatrix = transpose(inverse(mat3(modelviewMatrix)));
	vec3 n = normalize(normalMatrix * normal);

	vec4 camPosition = modelviewMatrix * vec4(position, 1.0);

	out_texCoord = uv;
	out_frontColor = phongModel(0, camPosition.xyz, n);
	out_backColor = phongModel(0, camPosition.xyz, -n);

	gl_Position = projectionMatrix * camPosition;
}
