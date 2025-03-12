#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float saturation <ui_min = 0; ui_max = 8.0; ui_type = "slider"; ui_label = "Saturation";> = 1;
uniform float final_lerp <ui_min = 0; ui_max = 2.0; ui_type = "slider"; ui_label = "Lerp";> = 1;

float3 SRGBtoOKLAB(float3 c) {
        float l = 0.4122214708f * c.r + 0.5363325363f * c.g + 0.0514459929f * c.b;
        float m = 0.2119034982f * c.r + 0.6806995451f * c.g + 0.1073969566f * c.b;
        float s = 0.0883024619f * c.r + 0.2817188376f * c.g + 0.6299787005f * c.b;
    
        float l_ = pow(l, rcp(3.0));
        float m_ = pow(m, rcp(3.0));
        float s_ = pow(s, rcp(3.0));
        
       return float3(
            0.2104542553f*l_ + 0.7936177850f*m_ - 0.0040720468f*s_,
            1.9779984951f*l_ - 2.4285922050f*m_ + 0.4505937099f*s_,
            0.0259040371f*l_ + 0.7827717662f*m_ - 0.8086757660f*s_);
}
        
float3 OKLABtoSRGB(float3 c) {
        float l_ = c.x + 0.3963377774f * c.y + 0.2158037573f * c.z;
        float m_ = c.x - 0.1055613458f * c.y - 0.0638541728f * c.z;
        float s_ = c.x - 0.0894841775f * c.y - 1.2914855480f * c.z;
    
        float l = l_*l_*l_;
        float m = m_*m_*m_;
        float s = s_*s_*s_;
    
        return float3(
             4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
            -1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
            -0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s);
}

void main(float4 vpos : SV_Position, float2 texcoord : Texcoord, out float4 res : SV_Target0) {
	res.a = 1;
	
	float3 base = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 lab = SRGBtoOKLAB(base);
	float chroma = sqrt(lab.y * lab.y + lab.z * lab.z); 
	float luma = lab.x;
	float3 luma3 = float3(luma, luma, luma);
	lab.yz = clamp(saturation * (lab.yz), -1, 1);
	

	float3 lin_srgb = OKLABtoSRGB(lab);
	res.rgb = lin_srgb;
	res.rgb = lerp(base, res.rgb, final_lerp);
}

technique DMargSaturation {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = main;
	}
}