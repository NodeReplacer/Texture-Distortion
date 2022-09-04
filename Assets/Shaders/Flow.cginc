#if !defined(FLOW_INCLUDED)
#define FLOW_INCLUDED

float3 FlowUVW (float2 uv, float2 flowVector, float2 jump, 
    float flowOffset, float tiling, float time, bool flowB) {
	//It may no longer be here but our first flow was moving the UV coordinates in relation to time. Just uv + time.
    
    float phaseOffset = flowB ? 0.5 : 0; //We started with one blend weight but that makes a very obvious transition as the whole
    //texture goes black
    float progress = frac(time + phaseOffset);
    float3 uvw; //Hiding the visual discontinuity that comes with resetting the animation. Because the test texture
    //just snaps back to big squares.
    //uvw.xy = uv - flowVector * progress + phaseOffset; //Subtracting the uv from flowVector * progress makes the flow go in the direction of
    //the vector.
    uvw.xy = uv - flowVector * (progress + flowOffset);
	uvw.xy *= tiling; //Separate the tiling for the texture because using the main tiling affects the flow map as well.
	uvw.xy += phaseOffset;
    
    uvw.xy += (time - progress) * jump; //jump is made to "jump" around the animation to prevent the loop from happening too quickly
    uvw.z = 1 - abs(1 - 2 * progress); //uvw.z is blend weight. it's used to fade to black to hide the sudden texture snapping 
    //back to its original form. At the time the texture is at its least deformed the blend weight is 0: Pitch black.
	return uvw;
}

float2 DirectionalFlowUV (float2 uv, float3 flowVectorAndSpeed, float tiling, float time, out float2x2 rotation) {
    /*
    Our first directional flow is here, where the pattern just moves by time.
    
    uv.y -= time;
	return uv * tiling;
    */
    float2 dir = normalize(flowVectorAndSpeed.xy);
	rotation = float2x2(dir.y, dir.x, -dir.x, dir.y);
    uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);
    uv.y -= time * flowVectorAndSpeed.z;
	return uv * tiling;
}

#endif