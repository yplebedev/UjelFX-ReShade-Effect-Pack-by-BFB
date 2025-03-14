/*
==============================================

All of MY code is licensed under CC0,
skipping some legal mumbo-jumbo, that means that you can do
basically everything.

This shader is free for all, forever.

==============================================
*/

#include "ReShadeUI.fxh"
#define vec3 float3
// OoOOOOoo vec3 scary
#define NOISE_TEX_NAME "UjelFX/QuarkBN - UJFX.png"
#define luma_coeff float3(0.2126, 0.7152, 0.0722)



/***
 *      _    _ _____ 
 *     | |  | |_   _|
 *     | |  | | | |  
 *     | |  | | | |  
 *     | |__| |_| |_ 
 *      \____/|_____|
 *                   
 *                   
 */


uniform bool bypass <ui_label = "Bypass all effects"; ui_tooltip = "Use this if you don't want any effects added from this shader, but want to use it for HDR extrapolation for other shaders.";> = false;

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
> = 0.4;

uniform int tonemapper<
	ui_type = "combo";
	ui_label = "Tonemapper";
	ui_tooltip = "Selects what function should be used for toning the image down.\nThis is your style option.\nMost functions are ports from https://github.com/dmnsgn/glsl-tone-map/";
	ui_items = "ACES\0Filmic\0Kronos Neutral\0Lottes\0Reinhard\0Reinhard, but better\0Uncharted 2\0AgX\0";
	ui_category = "Tonemapping";
> = 0;

uniform int aces_type<
	ui_type = "combo";
	ui_label = "ACES tonemapper type";
	ui_tooltip = "ACES is a SLOW function, and as such, UJHDR provides a few modes.";
	ui_items = "ACES Narkowicz\0My fit\0Unreal 3 fit\0Unreal Engine 4\0";
	ui_category = "ACES preferences";
> = 0;

uniform float slope <
	ui_type = "slider";
	ui_label = "Slope";
	ui_tooltip = "Use this to tweak the contrast";
	ui_category = "ACES preferences";
	ui_min = 0.01; ui_max = 1.0;
	> = 0.88;

uniform float toe <
	ui_type = "slider";
	ui_label = "Toe";
	ui_tooltip = "Use this to correct the shadows.";
	ui_category = "ACES preferences";
	ui_min = -1.0; ui_max = 4.0;
	> = 0.55;
	
uniform float shoulder <
	ui_type = "slider";
	ui_label = "Shoulder";
	ui_tooltip = "Use this to tweak the highlights.";
	ui_category = "ACES preferences";
	ui_min = -1.0; ui_max = 1.0;
	> = 0.26;
	
uniform float black_c <
	ui_type = "slider";
	ui_label = "Black Clip";
	ui_tooltip = "Use this to up the blacks.";
	ui_category = "ACES preferences";
	> = 0.0;
	
uniform float white_c <
	ui_type = "slider";
	ui_label = "White Clip";
	ui_tooltip = "Use this to fix the whites.";
	ui_category = "ACES preferences";
	> = 0.04;


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
> = 0.1;

uniform float bloom_sat <
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_label = "Bloom desaturation";
	ui_tooltip = "How saturated the bloom is. Can be used as a smarter way to add color, or to inverse the bloom chroma entirely.\nHowever, this is based on luma -> default lerping, and isn't particularly accurate.";
	ui_category = "Bloom";
> = 0.2;

//uniform bool bloom_dissolve <ui_label = "Do noisy mixing for bloom"; ui_category = "Bloom";> = false;
uniform float dissolve_lerp <ui_label = "Noisy mixing method"; ui_category = "Bloom"; ui_min = 0; ui_max = 1; ui_type = "slider";> = 1.0;

texture noise < source = NOISE_TEX_NAME; > { Width = 512; Height = 512; Format = RGBA8; };
sampler dissolve { Texture = noise; MagFilter = POINT; MinFilter = POINT;
	AddressU = REPEAT;
	AddressV = REPEAT;
	AddressW = REPEAT; };

uniform float post_exposure < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 5.0;
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
#include "UjelFX_includes/UjelUtilities.fxh"



/***
 *      _____         _____ _____ ______  _____ 
 *     |  __ \ /\    / ____/ ____|  ____|/ ____|
 *     | |__) /  \  | (___| (___ | |__  | (___  
 *     |  ___/ /\ \  \___ \\___ \|  __|  \___ \ 
 *     | |  / ____ \ ____) |___) | |____ ____) |
 *     |_| /_/    \_\_____/_____/|______|_____/ 
 *                                              
 *                                              
 */


// BLURRING STUFF! 
// Slightly modified code, og by zenteon, beeg ty!
// FYI this was mostly moved to a header file, code looks a bit less ass now..


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

float3 prepare(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target { 
	float3 i = inv_t(tex2D(ReShade::BackBuffer, texcoord).rgb);
	float luma = dot(i.rgb, luma_coeff);
	return lerp(i, luma, bloom_sat);
}


float4 final(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target {
	float4 res = 0.0;
	float4 bb = tex2D(ReShade::BackBuffer, texcoord);
	float3 bloom = tex2D(BSam5, texcoord).rgb;
	float3 base = inv_t(bb.rgb);
	
	float3 composite = float3(0, 0, 0);
	if (dissolve_lerp == 1) {
		composite = lerp(base, bloom, bloom_strength);
	} else {
		float rand = saturate(tex2Dfetch(dissolve, vpos.xy % 512).r);
		if (rand < bloom_strength) composite = bloom;
		else composite = base;
		composite = lerp(composite, lerp(base, bloom, bloom_strength), dissolve_lerp);
	}
	
	composite *= post_exposure;
	switch (hdr_mode) {
		case (0): res.rgb = lerp(lottes(composite), tonemap(composite), tonemapping_strength); break;
		case (1): res.rgb = lerp(reinhard(composite), tonemap(composite), tonemapping_strength); break;
		case (2): res.rgb = lerp(aces(composite), tonemap(composite), tonemapping_strength); break;
	}
	if (bypass) return bb;
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
		RenderTarget = BTex2;
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