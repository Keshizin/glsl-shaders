#version 450 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec4 baseColor;
layout (location = 2) in vec2 uv;
layout (location = 3) in vec3 normal;
layout (location = 4) in mat4 modelMatrix; // one modelview matrix per instance


// total of lights
const int TOTAL_OF_LIGHTS = 10;


// source light info
uniform struct LightInfo {
	vec3 position;
	vec3 La;
	vec3 Ld;
	vec3 Ls;
	int source_type; // 0 - single point, 1 - directional, 2 - spot
	vec3 spot_direction;
	float spot_cutoff;
	float spot_exponent;
} lights[TOTAL_OF_LIGHTS];


// material info
uniform struct MaterialInfo {
	vec3 Ka;
	vec3 Kd;
	vec3 Ks;
	float shininess;
} material;


// lighting model info
uniform struct LightingModelInfo {
	int non_local_viewer;
	int is_two_sided;
	int flat_shading;
	int model_type;
} lightingModel;


// fog info
uniform struct FogInfo
{
	float max_distance;
	float min_distance;
	vec3 color;
	int enable;
} fog;

// uniform variable data
uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;


// out variable
layout (location = 3) out vec3 out_lightColor;
layout (Location = 4) flat out vec3 out_flatLightColor;


// diffuse reflection model
vec3 diffuseModel(vec3 v, vec3 n)
{
	vec3 light = vec3(0.0);
	vec3 s;
	vec3 lightPosition;
	float dotResult;

	for(int index = 0; index < TOTAL_OF_LIGHTS; index++)
	{
		lightPosition = (viewMatrix * vec4(lights[index].position, 1.0)).xyz;

		if(lights[index].source_type == 0)
			// single point
			s = normalize(lightPosition - v);
		else
			// directional
			s = normalize(lightPosition);

		dotResult = max(dot(s, n), 0.0);;

		light += lights[index].Ld * material.Kd * dotResult;
	}

	return light;
}


// phong model reflection
vec3 phongModel(vec3 v, vec3 n)
{
	vec3 light = vec3(0.0);
	vec3 ambient;
	vec3 s;
	vec3 lightPosition;
	float dotResult;
	vec3 diffuse;

	for(int index = 0; index < TOTAL_OF_LIGHTS; index++)
	{
		// compute ambient light
		ambient = lights[index].La * material.Ka;

		// compute diffuse light
		lightPosition = (viewMatrix * vec4(lights[index].position, 1.0)).xyz;

		// 0 - single point
		// 1 - directional
		// 2 - spot
		if(lights[index].source_type == 0 || lights[index].source_type == 2)
			// single point or spot
			s = normalize(lightPosition - v);
		else
			// directional
			s = normalize(lightPosition);

		dotResult = max(dot(s, n), 0.0);;
		diffuse = lights[index].Ld * material.Kd * dotResult;

		float spotScale = 1.0f;

		if(lights[index].source_type == 2)
		{
			vec3 spotDirection = (viewMatrix * vec4(-lights[index].spot_direction, 1.0)).xyz;

			float cosAngle = dot(-s, normalize(spotDirection));
			float angle = acos(cosAngle);
		
			if(angle < lights[index].spot_cutoff)
				spotScale = pow(cosAngle, lights[index].spot_exponent);
			else
				spotScale = 0.0f;
		}

		// compute specular highlight
		vec3 specular = vec3(0.0);

		if(dotResult > 0.0)
		{
			if(lightingModel.non_local_viewer == 1)
				v = vec3(0.0, 0.0, 1.0);
			else
				v = normalize(-v);

			vec3 r = reflect(-s, n);
			specular = lights[index].Ls * material.Ks * pow( max( dot(r, v), 0.0), material.shininess);
		}

		light += ambient + spotScale * (diffuse + specular);
	}

	return light;
}


// blinn-phong model reflection
vec3 blinnPhongModel(vec3 v, vec3 n)
{
	vec3 light = vec3(0.0);
	vec3 ambient;
	vec3 s;
	vec3 lightPosition;
	float dotResult;
	vec3 diffuse;

	for(int index = 0; index < TOTAL_OF_LIGHTS; index++)
	{
		// compute ambient light
		ambient = lights[index].La * material.Ka;

		// compute diffuse light
		lightPosition = (viewMatrix * vec4(lights[index].position, 1.0)).xyz;

		// 0 - single point
		// 1 - directional
		// 2 - spot
		if(lights[index].source_type == 0 || lights[index].source_type == 2)
			// single point
			s = normalize(lightPosition - v);
		else
			// directional
			s = normalize(lightPosition);

		dotResult = max(dot(s, n), 0.0);;
		diffuse = lights[index].Ld * material.Kd * dotResult;

		float spotScale = 1.0f;

		if(lights[index].source_type == 2)
		{
			vec3 spotDirection = (viewMatrix * vec4(-lights[index].spot_direction, 1.0)).xyz;

			float cosAngle = dot(-s, normalize(spotDirection));
			float angle = acos(cosAngle);
		
			if(angle < lights[index].spot_cutoff)
				spotScale = pow(cosAngle, lights[index].spot_exponent);
			else
				spotScale = 0.0f;
		}

		// compute specular highlight
		vec3 specular = vec3(0.0);

		if(dotResult > 0.0)
		{
			if(lightingModel.non_local_viewer == 1)
				v = vec3(0.0, 0.0, 1.0);
			else
				v = normalize(-v);

			// blinn-phong shading
			vec3 h = normalize(v + s);
			specular = lights[index].Ls * material.Ks * pow( max( dot(h, n), 0.0), material.shininess);
		}

		light += ambient + spotScale * (diffuse + specular);
	}

	return light;
}


// mixing fog color with shading color
vec3 fogMixColor(vec3 shadeColor, vec3 position)
{
	vec3 color = vec3(0.0);
	float d = abs(position.z);
	float fogFactor = (fog.max_distance - d) / (fog.max_distance - fog.min_distance);

	fogFactor = clamp(fogFactor, 0.0, 1.0);
	color = mix(fog.color, shadeColor, fogFactor);
	return color;
}


void main()
{
	mat4 modelViewMatrix = viewMatrix * modelMatrix;

	// getting the normal matrix transformation from modelview matrix transformation
	mat3 eyeMatrix = transpose(inverse(mat3(modelViewMatrix)));
	vec3 transfomedNormal = normalize(eyeMatrix * normal);

	// getting only the eye space position
	vec4 eyePosition = modelViewMatrix * vec4(position, 1.0);

	if(lightingModel.is_two_sided == 1)
	{
		float vDotN = dot(-eyePosition.xyz, transfomedNormal);
		
		if(vDotN < 0)
			transfomedNormal = -transfomedNormal;
	}

	out_lightColor = vec3(0.0);

	// 0 - diffuse reflection model (lambertiana)
	// 1 - phong reflection model
	// 2 - blinn-phong reflection model

	if(lightingModel.model_type == 0)
		out_lightColor = diffuseModel(eyePosition.xyz, transfomedNormal);
	else if(lightingModel.model_type == 1)
		out_lightColor = phongModel(eyePosition.xyz, transfomedNormal);
	else if(lightingModel.model_type == 2)
		out_lightColor = blinnPhongModel(eyePosition.xyz, transfomedNormal);

	// mixing fog color
	if(fog.enable == 1)
		out_lightColor = fogMixColor(out_lightColor, eyePosition.xyz);

	out_flatLightColor = out_lightColor;



	// column-major order -> proj * view * model * position
	gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
