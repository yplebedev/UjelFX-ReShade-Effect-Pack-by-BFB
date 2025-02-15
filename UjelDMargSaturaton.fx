#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float Epsilon = 1e-10;

uniform float saturation <ui_min = 0; ui_max = 3.0; ui_type = "slider"; ui_label = "Saturation";> = 1;
uniform float final_lerp <ui_min = 0; ui_max = 1.0; ui_type = "slider"; ui_label = "Lerp";> = 0.5;

uniform bool grit_mode<ui_label = "Enable desaturation only";> = false;

float3 RGBtoHCV(in float3 RGB) {
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
}

float3 RGBtoHSL(float3 RGB) {
    float3 HCV = RGBtoHCV(RGB);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1 - abs(L * 2 - 1) + Epsilon);
    return float3(HCV.x, S, L);
}

void main(float2 texcoord : Texcoord, out float4 res : SV_Target0) {
	res.a = 1;
	
	float3 base = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 hsl = RGBtoHSL(base);
	float luma = hsl.b;
	float3 luma3 = float3(luma, luma, luma);
	
	float3 desaturated = lerp(base, luma3, hsl.g);
	float desaturated_luma = RGBtoHSL(desaturated).b;
	float3 resaturated = lerp(desaturated_luma, desaturated, saturation);
	

	
	if (grit_mode) {
		res.rgb = desaturated;
	} else { res.rgb = lerp(base, resaturated, final_lerp); }
}

technique DMargSaturation {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = main;
	}
}