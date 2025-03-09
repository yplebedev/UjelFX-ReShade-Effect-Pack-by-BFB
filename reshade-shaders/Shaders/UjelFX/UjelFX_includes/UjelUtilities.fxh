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


texture pretex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler pretex_sampler { Texture = pretex; };

float max3(float x, float y, float z) {
	return max(x, max(y, z)); 
}

float3 inv_t(float3 t) {
	t *= pre_exposure;
    t = pow(saturate(t), 2.2);
    switch (hdr_mode) {
    case (1) :
    	float luma = dot(t, luma_coeff);
    	float3 chroma = t - float3(luma, luma, luma);
    	float luma_tonemapped = max(-luma / (luma - 1 - rcp(hdr_modifier)), 0.0);
    	return lerp(luma_tonemapped + chroma, max(-t / (t - 1 - rcp(hdr_modifier)), 0.0), reinhard_saturation);
    case (0) :
    	return t * rcp(max(1.0 - max3(t.r, t.g, t.b) * hdr_modifier / 10, 0.1));
    }
    return (sqrt(-10127. * t * t + 13702. * t + 9.) + 59. * t - 3.) / (502. - 486. * t);
}

float3 unreal(float3 x) {
  return x / (x + 0.155) * 1.019;
}

float aces_per_channel(float x) {
	x = log10(x);
	float s = 1.0; // whitepoint, i gather.
	float ga = slope;
	float t0 = toe;
	float t1 = black_c;
	float s0 = shoulder;
	float s1 = white_c;
	
	float ta = (1.0 - t0 - 0.18) / ga - 0.733;
	float sa = (s0 - 0.18) / ga - 0.733;
	float result = 0.0;
	if (x < ta) {
		result = s * (2 * (1.0 + t1 - t0) / (1.0 + exp(-2 * ga * (x - ta) / (1 + t1 - t0))) - t1);
	} else if (x < sa) {
		result = s * (ga * (x + 0.733) + 0.18);
	} else {
		result = s * (1.0 + s1 - 2 * (1 + s1 - s0) / (1.0 + exp(2 * ga * (x - sa) / (1 + s1 - s0))));
	}
	return result;
}

float3 aces(float3 x) {
// My own fit,
// Unreal Engine 4 ACESFilm implementation,
// Narkowicz 2015, "ACES Filmic Tone Mapping Curve",
// and unreal3.
// not in any real order.
	float3 res = float3(0., 0., 0.);
	switch (aces_type) {
		case (0):
	  	const float a = 2.51;
	 	 const float b = 0.03;
	  	const float c = 2.43;
	  	const float d = 0.59;
	  	const float e = 0.14;
	 	 res = clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
	 	 break;
		case (1):
			res = smoothstep(x / (0.8 * pow(x - 1, 3) + 6.3), 0, 1);
			break;
		case (2):
			res = unreal(x);
			break;
			
		case (3):	
			res.r = aces_per_channel(x.r);		
			res.g = aces_per_channel(x.g);
			res.b = aces_per_channel(x.b);
			//res = pow(1/10, res);
			break;
	}
	return res;
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

  return pow(pow(x, a) / (pow(x, a * d) * b + c), rcp(gamma_correct));
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

float3 ujel(float3 x) {
	// Only tonemapper made by me. 
	// It's admittedly a sad attemt, and it maps [0, 5] to [0, something subtly lower then 1]
	float3 p = clamp(x, 0, 5);
	float3 z = pow(p, 2.4);
	return clamp(z * 0.48773612105 / (pow(p, 3.3) * 0.1 + 2), 0, 1);
}

float3 tonemap(float3 x) {
	switch (tonemapper) {
		case (0) : return aces(x);
		case (1) : return filmic(x); 
		case (2) : return neutral(x); 
		case (3) : return lottes(x); 
		case (4) : return reinhard(x); 
		case (5) : return reinhard2(x); 
		case (6) : return uncharted2(x);  
		case (7) : return ujel(x); 
	}
	return pow(x, rcp(gamma_correct));
}