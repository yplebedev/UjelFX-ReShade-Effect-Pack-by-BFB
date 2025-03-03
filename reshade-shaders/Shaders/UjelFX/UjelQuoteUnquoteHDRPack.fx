#include "ReShadeUI.fxh"
#define vec3 float3
// fuck

uniform float hdr_modifier < __UNIFORM_SLIDER_FLOAT1
	ui_min = 1.0; ui_max = 20;
	ui_label = "HDR modifier";
	ui_tooltip = "How much to stretch out the highlights into HDR. Only defined for Lottes and Reinhard.\nFor Lottes, it acts as a multiplier, while for Reinhard it sets the whitepoint directly.";
	ui_category = "Inverse Tonemapping";
> = 0.1;

uniform int hdr_mode <
	ui_type = "combo"; ui_label = "HDR Extrapolation algorithm";
	ui_items = "Lottes\0Reinhard\0ACES\0";
	ui_category = "Inverse Tonemapping";
> = 0;

uniform float reinhard_saturation <ui_min = 0.0; ui_max = 1; ui_type = "slider";
	ui_label = "Reinhard saturation intensity";
	ui_category = "Inverse Tonemapping";
> = 0.7;

uniform float pre_exposure < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "IN exposure";
	ui_category = "Inverse Tonemapping";
> = 1;

uniform float tonemapping_strength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Tonemapping intensity";
	ui_tooltip = "A lerp between tonemapping with lottes, giving a more netural look, and a selected method.";
	ui_category = "Tonemapping";
> = 1;

uniform int tonemapper<
	ui_type = "combo";
	ui_label = "Tonemapper";
	ui_tooltip = "Selects what function should be used for toning the image down.\nThis is your style option.\nMost functions are ports from https://github.com/dmnsgn/glsl-tone-map/";
	ui_items = "ACES\0Filmic\0Kronos Neutral\0Lottes\0Reinhard\0Reinhard, but better\0Uncharted 2\0Unreal 3\0BFB's Own Tonemapper (VERY, VERY GRIYTTY)\0";
	ui_category = "Tonemapping";
> = 0;

uniform float blur_offset <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 20.0;
	ui_label = "Blur radius";
	ui_tooltip = "Fine-tune the radius of the blur.";
	ui_category = "Bloom";
> = 15.0;

uniform float bloom_strength <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_label = "Bloom intensity";
	ui_tooltip = "How much bloom to add.";
	ui_category = "Bloom";
> = 0.2;

uniform float bloom_sat <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_label = "Bloom desaturation";
	ui_tooltip = "How saturated the bloom is. Can be used as a smarter way to add color, or to inverse the bloom chroma entirely.\nHowever, this is based on luma -> default lerping, and isn't particularly accurate.";
	ui_category = "Bloom";
> = 0.2;

uniform bool bloom_dissolve <ui_label = "[ToDo!] Do dissolve mixing for bloom"; ui_category = "Bloom";> = false;

texture noise <source = "ujeldissolve.png";> { Width = 512; Height = 512; Format = RGBA8; };
sampler dissolve { Texture = noise; };

uniform float post_exposure < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "OUT exposure";
	ui_category = "Corrections";
> = 1;

uniform float saturate_mid_fac< __UNIFORM_SLIDER_FLOAT1
	ui_min = -2.0; ui_max = 2.0;
	ui_label = "Affect only midtones [USE SEPARATE SHADER]";
	ui_category = "Corrections";
> = 0.0;

uniform float saturation< __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Saturation [USE SEPARATE SHADER]";
	ui_category = "Corrections";
> = 1;

uniform float gamma_correct <ui_category = "Corrections";> = 2.2;

#include "ReShade.fxh"


texture pretex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler pretex_sampler { Texture = pretex; };

// BLURRING STUFF! 
// Slightly modified code, og by zenteon, beeg ty!

// Old bs removed, thanks to papadanku for pointing out that this is a bit memory-inefficient.

texture BTex0 { Width = BUFFER_WIDTH / 32; Height = BUFFER_HEIGHT / 32; Format = RGBA16F; };
texture BTex1 { Width = BUFFER_WIDTH / 16; Height = BUFFER_HEIGHT / 16; Format = RGBA16F; };
texture BTex2 { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
texture BTex3 { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture BTex4 { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA16F; };
texture BTex5 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };

sampler BSam0 { Texture = BTex0; };
sampler BSam1 { Texture = BTex1; };
sampler BSam2 { Texture = BTex2; };
sampler BSam3 { Texture = BTex3; };
sampler BSam4 { Texture = BTex4; };
sampler BSam5 { Texture = BTex5; };

uniform float3 luma_coeff = float3(0.2126, 0.7152, 0.0722);

float4 Downsample(sampler samp, float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
    float4 acc = tex2D(samp, xy) * 4.0;
    float2 o1 = BUFFER_PIXEL_SIZE * blur_offset;
    float2 o2 = float2(o1.x, -o1.y);
    acc += tex2D(samp, xy - o1);
    acc += tex2D(samp, xy + o1);
    acc += tex2D(samp, xy + o2);
    acc += tex2D(samp, xy - o2);
    return acc / 8.0;
}

float4 DownSample0(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Downsample(pretex_sampler, vpos, xy);
}

float4 DownSample1(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Downsample(BSam4, vpos, xy);
}

float4 DownSample2(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Downsample(BSam3, vpos, xy);
}

float4 DownSample3(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Downsample(BSam2, vpos, xy);
}

float4 DownSample4(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Downsample(BSam1, vpos, xy);
}

float4 Upsample(sampler samp, float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target 
{
    float xo = BUFFER_RCP_WIDTH * blur_offset;
    float yo = BUFFER_RCP_HEIGHT * blur_offset;
    float xo2 = xo * 2;
    float yo2 = yo * 2;
	float4 acc = 
		tex2D(samp, xy + float2(-xo, yo)) +
    	tex2D(samp, xy + float2(xo, yo)) +
		tex2D(samp, xy + float2(xo, -yo)) + 
    	tex2D(samp, xy + float2(-xo, -yo));
    acc *= 2;
    acc += tex2D(samp, xy + float2(-xo2, 0.0));
    acc += tex2D(samp, xy + float2(0.0, yo2));
    acc += tex2D(samp, xy + float2(xo2, 0.0));
    acc += tex2D(samp, xy + float2(0.0, -yo2));
    return acc / 12.0;
}

float4 UpSample0(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Upsample(BSam0, vpos, xy);
}

float4 UpSample1(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Upsample(BSam1, vpos, xy);
}

float4 UpSample2(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Upsample(BSam2, vpos, xy);

}

float4 UpSample3(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Upsample(BSam3, vpos, xy);
}

float4 UpSample4(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	return Upsample(BSam4, vpos, xy);
}

float max3(float x, float y, float z) {
	return max(x, max(y, z)); 
}

float3 inv_t(float3 t) {
	t *= pre_exposure;
    t = pow(saturate(t), 2.2);
    if (hdr_mode == 1) {
    	float luma = dot(t, luma_coeff);
    	float3 chroma = t - float3(luma, luma, luma);
    	float luma_tonemapped = max(-luma / (luma - 1 - rcp(hdr_modifier)), 0.0);
    	return lerp(luma_tonemapped + chroma, max(-t / (t - 1 - rcp(hdr_modifier)), 0.0), reinhard_saturation);
    }
    if (hdr_mode == 0) {
    	return t * rcp(max(1.0 - max3(t.r, t.g, t.b) * hdr_modifier / 10, 0.1));
    }
    return (sqrt(-10127. * t * t + 13702. * t + 9.) + 59. * t - 3.) / (502. - 486. * t);
}

float3 t(float3 t) {
	float3 max = max3(t.r, t.g, t.b);
	return t * rcp(max + 1.0);
}

float3 aces(float3 x) {
// Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float3 neutral(float3 color) {
  const float startCompression = 0.8 - 0.04;
  const float desaturation = 0.15;

  float x = min(color.r, min(color.g, color.b));
  float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
  color -= offset;

  float peak = max(color.r, max(color.g, color.b));
  if (peak < startCompression) return color;

  const float d = 1.0 - startCompression;
  float newPeak = 1.0 - d * d / (peak + d - startCompression);
  color *= newPeak / peak;

  float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
  return lerp(color, float3(newPeak, newPeak, newPeak), g);
}

// Filmic Tonemapping Operators http://filmicworlds.com/blog/filmic-tonemapping-operators/
float3 filmic(float3 x) {
  float3 X = max(float3(0.0, 0.0, 0.0), x - 0.004);
  float3 result = (X * (6.2 * X + 0.5)) / (X * (6.2 * X + 1.7) + 0.06);
  return result;
}

vec3 lottes(vec3 x) {
  const vec3 a = vec3(1.6, 1.6, 1.6);
  const vec3 d = vec3(0.977, 0.977, 0.977);
  const vec3 hdrMax = vec3(8.0, 8.0, 8.0);
  const vec3 midIn = vec3(0.18, 0.18, 0.18);
  const vec3 midOut = vec3(0.267, 0.267, 0.267);

  const vec3 b =
      (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
      ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
  const vec3 c =
      (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
      ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

  return pow(x, a) / (pow(x, a * d) * b + c);
}

vec3 reinhard(vec3 x) {
  return pow(x / (1.0 + x), rcp(gamma_correct));
}

vec3 reinhard2(vec3 x) {
  const float L_white = 4.0;
  return (x * (1.0 + x / (L_white * L_white))) / (1.0 + x);
}

vec3 uncharted2Tonemap(vec3 x) {
  float A = 0.15;
  float B = 0.50;
  float C = 0.10;
  float D = 0.20;
  float E = 0.02;
  float F = 0.30;
  float W = 11.2;
  return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 uncharted2(vec3 color) {
  const float W = 11.2;
  float exposureBias = 2.0;
  vec3 curr = uncharted2Tonemap(exposureBias * color);
  vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W, W, W));
  return curr * whiteScale;
}

vec3 unreal(vec3 x) {
  return x / (x + 0.155) * 1.019;
}

float3 ujel(float3 x) {
	// Only tonemapper made by me. 
	// It's admittedly a sad attemt, and it maps [0, 5] to [0, something subtly lower then 1]
	float3 p = clamp(x, 0, 5);
	float3 z = pow(p, 2.4);
	return clamp(z * 0.48773612105 / (pow(p, 3.3) * 0.1 + 2), 0, 1);
}

float3 tonemap(float3 x) {
	if (tonemapper == 0) { return aces(x); }
	if (tonemapper == 1) { return filmic(x); }
	if (tonemapper == 2) { return neutral(x); }
	if (tonemapper == 3) { return lottes(x); }
	if (tonemapper == 4) { return reinhard(x); }
	if (tonemapper == 5) { return reinhard2(x); }
	if (tonemapper == 6) { return uncharted2(x); }
	if (tonemapper == 7) { return unreal(x); }
	if (tonemapper == 8) { return ujel(x); }
	return pow(x, rcp(gamma_correct));
}

float3 prepare(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target { 
	float3 i = inv_t(tex2D(ReShade::BackBuffer, texcoord).rgb);
	float luma = dot(i.rgb, luma_coeff);
	return lerp(i, luma, bloom_sat);
}


float4 final(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 res = 0.0;
	float3 bloom = tex2D(BSam5, texcoord).rgb;
	float3 base = inv_t(tex2D(ReShade::BackBuffer, texcoord).rgb);
	
	float3 composite = float3(0, 0, 0);
	if (!bloom_dissolve) {
		composite = lerp(base, bloom, bloom_strength);
	} else {
		float rand = tex2Dfetch(dissolve, texcoord).r;
		if (rand > bloom_strength) composite = bloom;
		else composite = base;
	}
	
	composite *= post_exposure;
	res.rgb = lerp(reinhard(composite), tonemap(composite), tonemapping_strength);
	return res;
}


technique BFBsHDR {
	pass prepare {
		VertexShader = PostProcessVS;
		PixelShader = prepare;
		RenderTarget = pretex;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample0;
		RenderTarget = BTex4;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample1;
		RenderTarget = BTex3;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample2;
		RenderTarget = BTex2
;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample3;
		RenderTarget = BTex1;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample4;
		RenderTarget = BTex0;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample0;
		RenderTarget = BTex1;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample1;
		RenderTarget = BTex2;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample2;
		RenderTarget = BTex3;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample3;
		RenderTarget = BTex4;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample4;
		RenderTarget = BTex5;
	}

	pass final{
		VertexShader = PostProcessVS;
		PixelShader = final;
	}
}