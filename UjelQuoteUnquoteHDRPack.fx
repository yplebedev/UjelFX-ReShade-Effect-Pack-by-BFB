#include "ReShadeUI.fxh"



uniform float hdr_modifier < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 0.999;
	ui_label = "HDR Mofifier";
> = 0.1;


uniform float pre_exposure < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "IN exposure";
> = 1;

uniform float post_exposure < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "OUT exposure";
> = 1;

uniform float saturation< __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 2.0;
	ui_label = "Saturation to compensate";
> = 1;

uniform float saturate_mid_fac< __UNIFORM_SLIDER_FLOAT1
	ui_min = -2.0; ui_max = 2.0;
	ui_label = "Affect only midtones";
> = 0.0;

uniform float final_lerp <__UNIFORM_SLIDER_FLOAT1
	ui_min = 0; ui_max = 2.0;
	ui_label = "Effect strength";
> = 1.0;

uniform float blur_offset <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 20.0;
	ui_label = "Blur Offset";
	ui_tooltip = "Blur radius";
> = 15.0;

uniform float bloom_strength <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_label = "Bloom intensity";
	ui_tooltip = "How much bloom to add.";
> = 0.2;


uniform float gamma_correct <> = 1;

#include "ReShade.fxh"

// BLURRING STUFF! 
// HEAVILY inspired by zenteon, beeg ty!

texture DTex0 { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA8; };
texture DTex1 { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA8; };
texture DTex2 { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA8; };
texture DTex3 { Width = BUFFER_WIDTH / 16; Height = BUFFER_HEIGHT / 16; Format = RGBA8; };
texture UTex0 { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA8; };
texture UTex1 { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA8; };
texture UTex2 { Width = BUFFER_WIDTH / 2; Height = BUFFER_HEIGHT / 2; Format = RGBA8; };
texture UTex3 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

sampler DownSam0 { Texture = DTex0; };
sampler DownSam1 { Texture = DTex1; };
sampler DownSam2 { Texture = DTex2; };
sampler DownSam3 { Texture = DTex3; };
sampler UpSam0 { Texture = UTex0; };
sampler UpSam1 { Texture = UTex1; };
sampler UpSam2 { Texture = UTex2; };
sampler UpSam3 { Texture = UTex3; };

float4 DownSample0(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;

    float3 acc = tex2D(ReShade::BackBuffer, xy).rgb * 4.0;
    acc += tex2D(ReShade::BackBuffer, xy - hp * offset).rgb;
    acc += tex2D(ReShade::BackBuffer, xy + hp * offset).rgb;
    acc += tex2D(ReShade::BackBuffer, xy + float2(hp.x, -hp.y) * offset).rgb;
    acc += tex2D(ReShade::BackBuffer, xy - float2(hp.x, -hp.y) * offset).rgb;

    return float4(acc / 8.0, 1.0);

}

float4 DownSample1(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;

    float3 acc = tex2D(DownSam0, xy).rgb * 4.0;
    acc += tex2D(DownSam0, xy - hp * offset).rgb;
    acc += tex2D(DownSam0, xy + hp * offset).rgb;
    acc += tex2D(DownSam0, xy + float2(hp.x, -hp.y) * offset).rgb;
    acc += tex2D(DownSam0, xy - float2(hp.x, -hp.y) * offset).rgb;

    return float4(acc / 8.0, 1.0);

}

float4 DownSample2(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;

    float3 acc = tex2D(DownSam1, xy).rgb * 4.0;
    acc += tex2D(DownSam1, xy - hp * offset).rgb;
    acc += tex2D(DownSam1, xy + hp * offset).rgb;
    acc += tex2D(DownSam1, xy + float2(hp.x, -hp.y) * offset).rgb;
    acc += tex2D(DownSam1, xy - float2(hp.x, -hp.y) * offset).rgb;

    return float4(acc / 8.0, 1.0);

}

float4 DownSample3(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;

    float3 acc = tex2D(DownSam1, xy).rgb * 4.0;
    acc += tex2D(DownSam2, xy - hp * offset).rgb;
    acc += tex2D(DownSam2, xy + hp * offset).rgb;
    acc += tex2D(DownSam2, xy + float2(hp.x, -hp.y) * offset).rgb;
    acc += tex2D(DownSam2, xy - float2(hp.x, -hp.y) * offset).rgb;

    return float4(acc / 8.0, 1.0);

}

float4 UpSample0(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;
	float3 acc = tex2D(DownSam3, xy + float2(-hp.x * 2.0, 0.0) * offset).rgb;
    
    acc += tex2D(DownSam3, xy + float2(-hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(DownSam3, xy + float2(0.0, hp.y * 2.0) * offset).rgb;
    acc += tex2D(DownSam3, xy + float2(hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(DownSam3, xy + float2(hp.x * 2.0, 0.0) * offset).rgb;
    acc += tex2D(DownSam3, xy + float2(hp.x, -hp.y) * offset).rgb * 2.0;
    acc += tex2D(DownSam3, xy + float2(0.0, -hp.y * 2.0) * offset).rgb;
    acc += tex2D(DownSam3, xy + float2(-hp.x, -hp.y) * offset).rgb * 2.0;

    return float4(acc / 12.0, 1.0);
}



float4 UpSample1(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;
	float3 acc = tex2D(UpSam0, xy + float2(-hp.x * 2.0, 0.0) * offset).rgb;
    
    acc += tex2D(UpSam0, xy + float2(-hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam0, xy + float2(0.0, hp.y * 2.0) * offset).rgb;
    acc += tex2D(UpSam0, xy + float2(hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam0, xy + float2(hp.x * 2.0, 0.0) * offset).rgb;
    acc += tex2D(UpSam0, xy + float2(hp.x, -hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam0, xy + float2(0.0, -hp.y * 2.0) * offset).rgb;
    acc += tex2D(UpSam0, xy + float2(-hp.x, -hp.y) * offset).rgb * 2.0;

    return float4(acc / 12.0, 1.0);
}

float4 UpSample2(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;
	float3 acc = tex2D(UpSam0, xy + float2(-hp.x * 2.0, 0.0) * offset).rgb;
    
    acc += tex2D(UpSam1, xy + float2(-hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam1, xy + float2(0.0, hp.y * 2.0) * offset).rgb;
    acc += tex2D(UpSam1, xy + float2(hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam1, xy + float2(hp.x * 2.0, 0.0) * offset).rgb;
    acc += tex2D(UpSam1, xy + float2(hp.x, -hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam1, xy + float2(0.0, -hp.y * 2.0) * offset).rgb;
    acc += tex2D(UpSam1, xy + float2(-hp.x, -hp.y) * offset).rgb * 2.0;

    return float4(acc / 12.0, 1.0);
}

float4 UpSample3(float4 vpos : SV_Position, float2 xy : TexCoord) : SV_Target
{
	//float2 xy = texcoord;
	float2 res = float2(BUFFER_WIDTH, BUFFER_HEIGHT) / 2.0;
    float2 hp = 0.5 / res;
    float offset = blur_offset;
	float3 acc = tex2D(UpSam2, xy + float2(-hp.x * 2.0, 0.0) * offset).rgb;
    
    acc += tex2D(UpSam2, xy + float2(-hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam2, xy + float2(0.0, hp.y * 2.0) * offset).rgb;
    acc += tex2D(UpSam2, xy + float2(hp.x, hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam2, xy + float2(hp.x * 2.0, 0.0) * offset).rgb;
    acc += tex2D(UpSam2, xy + float2(hp.x, -hp.y) * offset).rgb * 2.0;
    acc += tex2D(UpSam2, xy + float2(0.0, -hp.y * 2.0) * offset).rgb;
    acc += tex2D(UpSam2, xy + float2(-hp.x, -hp.y) * offset).rgb * 2.0;

    return float4(acc / 12.0, 1.0);
}



texture pretex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler pretex_sampler { Texture = pretex; };

float max3(float x, float y, float z) {
	return max(x, max(y, z)); 
}

float3 inv_t(float3 t) {
	float3 max = max3(t.r, t.g, t.b);
	return pow(t, gamma_correct) * rcp(1 - max * hdr_modifier) * pre_exposure;
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
  return pow(result, float3(2.2, 2.2, 2.2));
}

float3 prepare(float2 texcoord : TEXCOORD) : SV_Target { 
	return inv_t(tex2D(ReShade::BackBuffer, texcoord).rgb);
}


void final(float2 texcoord : TEXCOORD, out float4 res : SV_Target0) {
	float4 blurred = tex2D(UpSam3, texcoord);
	float3 base = inv_t(tex2D(ReShade::BackBuffer, texcoord).rgb);
	
	float3 bloom = lerp(base, blurred.rgb, bloom_strength);
	
	res.rgb = aces(bloom) * post_exposure;
	res.a = 1.0;
	float luma = dot(res.rgb, float3(0.229, 0.587, 0.114));
	float affected = abs(luma - 0.5) * saturate_mid_fac;
	res = lerp(float4(luma, luma, luma, 1.0), res, saturation - affected);
	res = lerp(base, res.rgb, final_lerp);
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
		RenderTarget = DTex0;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample1;
		RenderTarget = DTex1;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample2;
		RenderTarget = DTex2;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = DownSample3;
		RenderTarget = DTex3;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample0;
		RenderTarget = UTex0;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample1;
		RenderTarget = UTex1;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample2;
		RenderTarget = UTex2;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = UpSample3;
		RenderTarget = UTex3;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = final;
	}
}