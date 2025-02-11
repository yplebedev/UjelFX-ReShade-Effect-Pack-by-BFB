#include "ReShadeUI.fxh"

uniform float radius < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Radius";
> = 0.1;

uniform float strength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Blur lerp";
> = 0.1;

uniform float threshold < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "When to start adding bloom";
> = 0.1;

uniform float gamma < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 3.0;
	ui_label = "Gamma as set ingame";
> = 2.2;

uniform float maxparam < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 6.0;
	ui_label = "Inv tonemapping mult";
> = 1.0;

uniform float expComp <__UNIFORM_SLIDER_FLOAT1 ui_min = 0.0; ui_max = 2.0;> = 1;

uniform bool DEBUG_MASK <> = false;

uniform float finalLerp <__UNIFORM_SLIDER_FLOAT1 ui_min = 0.0; ui_max = 2.0; ui_label = "DeShittify this!";> = 1.0;




uniform float PHI = 1.61803398874989484820459;

#include "ReShade.fxh"

uniform int framecount < source = "framecount"; >;
uniform float frametime < source = "frametime"; >;

float gold_noise(float2 xy, float seed) {
    return frac(tan(distance(xy*PHI, xy)*seed)*xy.y);
}

float gauss_noise(float2 xy, float seed, int samples) {
	float accum = 0;
	for (int i = 0; i < samples; i++) {
		accum += gold_noise(xy, seed + i / PHI) - 0.5;
	}
	return accum / samples;
}

float max3(float x, float y, float z) {
	if (maxparam == 1.0) {
	return max(x, max(y, z)); }
	return maxparam;
}

float3 inv_t(float3 sdr) {
	float3 t = expComp * sdr;
	float3 max = max3(t.r, t.g, t.b);
	return t * rcp(0.9999 - max);
}

float3 t(float3 x) {
	//return hdr * rcp(max3(hdr.r, hdr.g, hdr.b) + 1);
  // Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}


void blur(float2 texcoord : TEXCOORD, out float4 result : SV_Target0) {
	float4 accumulator;
	int samples = 4;
	float2 uv = float2(texcoord.x * BUFFER_WIDTH, texcoord.y * BUFFER_HEIGHT); 
	for (int i = 0; i < samples; i++) {
		float noise0 = gauss_noise(uv, frac(frametime / PHI * (i + 1) + 0.5), 3);
		float noise1 = gauss_noise(uv, frac(frametime / PHI / PHI * (i + 1) + 0.2), 3);
		
		float2 offset = float2(noise0, 
		                       noise1
		);
		float ar = BUFFER_WIDTH / BUFFER_HEIGHT;
		offset = (offset) * float2(radius / ar, radius);
		accumulator += pow(tex2D(ReShade::BackBuffer, texcoord.xy + offset.xy), 1 / gamma);
	}
	accumulator = inv_t(accumulator);
	float3 base = pow(inv_t(tex2D(ReShade::BackBuffer, texcoord.xy).rgb), 1 / gamma);
	float luma = dot(base, float3(0.229, 0.587, 0.114));
	if (luma > threshold) {
		result = lerp(accumulator / samples, base, strength);
	} else {
		result = base;
	}
	result = t(pow(result, gamma));
	if (DEBUG_MASK) { if(luma > threshold) { result = 1; } }
	
	
	
	result.rgb = lerp(base.rgb, result.rgb, finalLerp);
}

technique BFBsBloomingHDR {
	pass APPLY_BLOOM {
		VertexShader = PostProcessVS;
		PixelShader = blur;
	}
}