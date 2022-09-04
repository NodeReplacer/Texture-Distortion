#if !defined(LOOKING_THROUGH_WATER_INCLUDED)
#define LOOKING_THROUGH_WATER_INCLUDED

sampler2D _CameraDepthTexture, _WaterBackground; //We have to know how far away something is below water. We can use the depth buffer to find
//this as all opaque objects have already been rendered. _CameraDepthTexture is Unity's globally available depth buffer.
float4 _CameraDepthTexture_TexelSize;

float3 _WaterFogColor;
float _WaterFogDensity;
float _RefractionStrength;

//Remove artifacting at edges of shapes that are above water by
float2 AlignWithGrabTexel (float2 uv) {
	#if UNITY_UV_STARTS_AT_TOP
		if (_CameraDepthTexture_TexelSize.y < 0) {
			uv.y = 1 - uv.y;
		}
	#endif

	return
		(floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) *
		abs(_CameraDepthTexture_TexelSize.xy);
}

float3 ColorBelowWater (float4 screenPos, float3 tangentSpaceNormal) {
    float2 uvOffset = tangentSpaceNormal.xy * _RefractionStrength;;
    uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
	float2 uv = AlignWithGrabTexel((screenPos.xy + uvOffset) / screenPos.w);
    #if UNITY_UV_STARTS_AT_TOP
		if (_CameraDepthTexture_TexelSize.y < 0) {
			uv.y = 1 - uv.y;
		}
	#endif
    float backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv)); //We sample the background depth
    //with SAMPLE_DEPTH_TEXTURE then convert the raw value to the linear depth with LinearEyeDepth.
    float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.z); //But the above is the depth relative to the screen,
    //we need the depth relative to the water surface.  We find the screen to water surface depth by taking the Z component
    //of screenPos (the interpolated clip space depth) and converting it to linear depth with the macro.
    float depthDifference = backgroundDepth - surfaceDepth;
	
	
    if (depthDifference < 0) {
		uv = AlignWithGrabTexel(screenPos.xy / screenPos.w);
		backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
		depthDifference = backgroundDepth - surfaceDepth;
	}
    
    float3 backgroundColor = tex2D(_WaterBackground, uv).rgb; //In GrabPass we use the texture _WaterBackground.
	float fogFactor = exp2(-_WaterFogDensity * depthDifference); //determine the fog's effect on the water using the depth of the water
    //and the given WaterFogDensity.
	return lerp(_WaterFogColor, backgroundColor, fogFactor); //linearly interpolate the fog color
    
	//return depthDifference / 20;
}

#endif