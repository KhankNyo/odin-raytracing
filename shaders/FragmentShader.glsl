#version 400 core


#define FLT_MAX 3.402823466e+38
#define NON_HIT_VALUE FLT_MAX
#define WORLD_OBJ_CAPACITY 32

#define MATERIAL_NORMAL_DEBUG 0
#define MATERIAL_PURE_COLOR 1
#define OBJ_SPHERE 0


struct obj_data 
{
	vec4 MaterialColor;
	vec4 Data;
	int MaterialType;
	int Type;
};

struct ray 
{
	vec3 Origin;
	vec3 Direction;
};



vec4 PixelDenormalize(vec4 Color)
{
	/* r/g/b are from 0..1, no need to denormalize since glsl accepts that range of value for color */
	return Color;
}


float Sphere_RayHits(ray Ray, vec3 SphereCenter, float SphereRadius)
{
	vec3 Dp = SphereCenter - Ray.Origin;
	float R = SphereRadius;

	/* dot() is a built-in */
	float A = dot(Ray.Direction, Ray.Direction);
	float B = -2.0f * dot(Ray.Direction, Dp);
	float C = dot(Dp, Dp) - R*R;

	float Discriminant = B*B - 4*A*C;
	if (Discriminant < 0.0)
	{
		return NON_HIT_VALUE;
	}

	/* don't care abt the other root bc it's too far */
	float ClosestHit = (-B - sqrt(Discriminant)) / (2.0f * A);
	return ClosestHit;
}

/* NOTE: render.odin uses NAN to signal non-hit condition, 
   I can't use NAN here bc it's implementation defined in glsl (may break on some gpu but run fine on others). 
   I used FLT_MAX instead
 */
float RayHits(ray Ray, int ObjType, vec4 ObjData)
{
	switch (ObjType)
	{
	case OBJ_SPHERE:
	{
		vec3 Origin = ObjData.xyz;
		float Radius = ObjData.w;
		return Sphere_RayHits(Ray, Origin, Radius);
	} break;
	default: 
	{
		return NON_HIT_VALUE;
	} break;
	}
}

vec3 RayAt(ray Ray, float Distance)
{
	vec3 Result = Ray.Origin + Ray.Direction * Distance;
	return Result;
}

vec3 SurfaceNormalAt(obj_data Obj, vec3 Point)
{
	vec3 Result;
	switch (Obj.Type)
	{
	case OBJ_SPHERE:
	{
		vec3 SphereCenter = Obj.Data.xyz;
		Result = normalize(Point - SphereCenter); /* built-in glsl function */
	} break;
	default:  
	{
		Result = vec3(0.0f);
	} break;
	}
	return Result;
}

vec4 ColorizeNormalVec(vec3 Normal)
{
	/* clamp -1..1 to 0..1 */
	vec3 Remapped = (Normal + 1.0) * 0.5;
	vec4 Result = vec4(Remapped, 1.0);
	return Result;
}

vec4 MaterialContributionAt(obj_data Obj, vec3 HitPoint, vec3 Normal)
{
	vec4 Result;
	switch (Obj.MaterialType)
	{
	case MATERIAL_NORMAL_DEBUG:
	{
		Result = ColorizeNormalVec(Normal);
	} break;
	case MATERIAL_PURE_COLOR:
	{
		Result = Obj.MaterialColor;
	} break;
	}
	return Result;
}


uniform int u_SamplesPerPixel;
uniform float u_SampleScalingFactor;
uniform vec3 u_VpOrigin;
uniform vec3 u_PixelDeltaX;
uniform vec3 u_PixelDeltaY;
uniform vec3 u_CamPos;
uniform vec4 u_SkyColor;
uniform int u_WorldObjCount;
uniform vec4 u_WorldObjData[WORLD_OBJ_CAPACITY];
uniform vec4 u_WorldObjMaterialColor[WORLD_OBJ_CAPACITY];
uniform int u_WorldObjType[WORLD_OBJ_CAPACITY];
uniform int u_WorldObjMaterialType[WORLD_OBJ_CAPACITY];
uniform float u_ScreenHeight;

out vec4 FragColor;

void main()
{
	float x = gl_FragCoord.x - 0.5;
	float y = u_ScreenHeight - gl_FragCoord.y - 0.5;
	vec4 Accum = vec4(0.0f);

	/* TODO: random sample in loop */
	float SampleXOffset = 0.1f;
	float SampleYOffset = 0.1f;
	for (int i = 0; i < u_SamplesPerPixel; i++)
	{
		vec3 PixelCenter = 
			u_VpOrigin 
			+ u_PixelDeltaX * (x + SampleXOffset) 
			+ u_PixelDeltaY * (y + SampleYOffset);

		ray ViewRay;
		ViewRay.Origin = u_CamPos;
		ViewRay.Direction = PixelCenter - u_CamPos;

		obj_data ClosestObj;
		float ClosestDst = FLT_MAX;
		for (int i = 0; i < u_WorldObjCount; i++)
		{
			float DstToObj = RayHits(ViewRay, u_WorldObjType[i], u_WorldObjData[i]);
			if (DstToObj != NON_HIT_VALUE && DstToObj < ClosestDst)
			{
				ClosestObj.Type = u_WorldObjType[i];
				ClosestObj.MaterialType = u_WorldObjMaterialType[i];
				ClosestObj.MaterialColor = u_WorldObjMaterialColor[i];
				ClosestObj.Data = u_WorldObjData[i];
				ClosestDst = DstToObj;
			}
		}

		if (ClosestDst == FLT_MAX)
		{
			/* did not hit anything */
			Accum += u_SkyColor;
		}
		else
		{
			/* hit something */
			vec3 HitLocation = RayAt(ViewRay, ClosestDst);
			vec3 HitNormal = SurfaceNormalAt(ClosestObj, HitLocation);
			Accum += MaterialContributionAt(ClosestObj, HitLocation, HitNormal);
		}

		/* NOTE: sampleX and sampleY range: 0.1..0.9 */
		SampleXOffset += 0.8f / 16.0f;
		SampleYOffset += 0.8f / 16.0f;
	}

	vec4 PixelColor = Accum * u_SampleScalingFactor;
	FragColor = PixelDenormalize(PixelColor);
}

