#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float saturation <ui_min = 0; ui_max = 8.0; ui_type = "slider"; ui_label = "Saturation";> = 1;
uniform float final_lerp <ui_min = 0; ui_max = 2.0; ui_type = "slider"; ui_label = "Lerp";> = 1;
uniform float desat_gamma <ui_min = 0; ui_max = 2.0; ui_type = "slider"; ui_label = "Desaturation squish";> = 1.0;
uniform bool do_overlay <ui_label = "Dark and Gritty";> = false;

uniform bool grit_mode<ui_label = "Enable desaturation only";> = false;


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

float3 overlay_mix(float3 top, float3 bottom, float strength) {
	float3 t = pow(top, 2.2);
	float3 b = pow(bottom, 2.2);
	float3 result = float3(0, 0, 0);
	if (b.r < 0.5) {
	    result.r = 2 * t.r * b.r;
	} else {
	    result.r = 1 - 2 * (1 - b.r) * (1 - t.r);
	} 
	if (b.g < 0.5) {
	    result.g = 2 * t.g * b.g;
	} else {
	    result.g = 1 - 2 * (1 - b.g) * (1 - t.g);
	}
	if (b.b < 0.5) {
	    result = 2 * t.b * b.b;
	} else {
	    result.b = 1 - 2 * (1 - b.b) * (1 - t.b);
	}
	result = pow(result, 1/2.2);
	// if i ever...
	return lerp(result, bottom, strength);
}

void main(float4 vpos : SV_Position, float2 texcoord : Texcoord, out float4 res : SV_Target0) {
	res.a = 1;
	
	float3 base = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 lab = SRGBtoOKLAB(base);
	float chroma = sqrt(lab.y * lab.y + lab.z * lab.z); 
	float luma = lab.x;
	float3 luma3 = float3(luma, luma, luma);
	
	float3 desaturated_by_sat = lerp(base, luma3, pow(chroma, desat_gamma));
	float3 desaturated_by_luma = lerp(base, luma3, pow(1 - luma, desat_gamma));
	float3 desaturated = lerp(desaturated_by_sat, desaturated_by_luma, 0.5);
	

	
	lab.yz = clamp(saturation * (lab.yz), -1, 1);
	

	float3 lin_srgb = OKLABtoSRGB(lab);
	res.rgb = lin_srgb;
	if (grit_mode) {
		res.rgb = desaturated;
	} else { 
		if (!do_overlay) {
			res.rgb = lerp(base, res.rgb, final_lerp);
		} else { res.rgb = overlay_mix(res.rgb, base.rgb, final_lerp); }
	}
}

technique DMargSaturation {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = main;
	}
}