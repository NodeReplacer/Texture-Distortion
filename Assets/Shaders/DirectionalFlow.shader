Shader "Custom/DirectionalFlow" {
	//Normal flow and directional flow will distort the texture differently.
    Properties {
		_Color ("Color", Color) = (1,1,1,1)
		[NoScaleOffset] _MainTex ("Deriv (AG) Height (B)", 2D) = "black" {}
		[NoScaleOffset] _FlowMap ("Flow (RG)", 2D) = "black" {}
		[Toggle(_DUAL_GRID)] _DualGrid ("Dual Grid", Int) = 0
        _Tiling ("Tiling, Constant", Float) = 1
		_TilingModulated ("Tiling, Modulated", Float) = 1
        _GridResolution ("Grid Resolution", Float) = 10 //Split the surface into tiles to manage the distortion, which is broken
        //even at time = 0. Our "resetting the time" strategy won't help here.
        _Speed ("Speed", Float) = 1
		_FlowStrength ("Flow Strength", Float) = 1
		_HeightScale ("Height Scale, Constant", Float) = 0.25
		_HeightScaleModulated ("Height Scale, Modulated", Float) = 0.75
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
        
		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows
		#pragma target 3.0
		#pragma shader_feature _DUAL_GRID
		#include "Flow.cginc"

		sampler2D _MainTex, _FlowMap;
		float _Tiling, _TilingModulated, _GridResolution, _Speed, _FlowStrength;
		float _HeightScale, _HeightScaleModulated;

		struct Input {
			float2 uv_MainTex;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;

		float3 UnpackDerivativeHeight (float4 textureData) {
			float3 dh = textureData.agb;
			dh.xy = dh.xy * 2 - 1;
			return dh;
		}
        
        float3 FlowCell (float2 uv, float2 offset, float time, float gridB) {
            //Changing the offset like this first allows us to sample the flow fromt he center. Without this it will sample from
            //the bottom left.
            float2 shift = 1 - offset;
		    shift *= 0.5;
            
            offset *= 0.5; //overlap each cell of the "grid" because otherwise we'll see seams between each square.
            if (gridB) {
		        offset += 0.25;
		        shift -= 0.25;
		    }
            float2x2 derivRotation;
            float2 uvTiled = (floor(uv * _GridResolution + offset) + shift) / _GridResolution;
            float3 flow = tex2D(_FlowMap, uvTiled).rgb;
			flow.xy = flow.xy * 2 - 1;
            flow.z *= _FlowStrength;
            float tiling = flow.z * _TilingModulated + _Tiling;
			float2 uvFlow = DirectionalFlowUV(uv + offset, flow, tiling, time, derivRotation);
            float3 dh = UnpackDerivativeHeight(tex2D(_MainTex, uvFlow));
            dh.xy = mul(derivRotation, dh.xy);
            dh *= flow.z * _HeightScaleModulated + _HeightScale; //Allow the strength of the derivative and the height data to be
            //scaled.
            return dh;
		}
        
        float3 FlowGrid (float2 uv, float time, bool gridB) { //This code samples and combines the four cells and returns the resulting
        //the result. we're trying to blend a result here so we have a second grid, gridB we'll use to mask our noise generation.
            //blend each square of the grid horizontally to avoid the seams that usually show up
            float3 dhA = FlowCell(uv, float2(0, 0), time, gridB);
            float3 dhB = FlowCell(uv, float2(1, 0), time, gridB);
            //blend the seams vertically
			float3 dhC = FlowCell(uv, float2(0, 1), time, gridB);
			float3 dhD = FlowCell(uv, float2(1, 1), time, gridB);
            
            //finalize the blending here
            float2 t = uv * _GridResolution;
			if (gridB) {
			    t += 0.25;
			}
			t = abs(2 * frac(t) - 1);
            //horizontally
            float wA = (1 - t.x) * (1 - t.y);
			float wB = t.x * (1 - t.y);
            //vertically
			float wC = (1 - t.x) * t.y;
			float wD = t.x * t.y;
            
            return dhA * wA + dhB * wB + dhC * wC + dhD * wD;
        }
        
		void surf (Input IN, inout SurfaceOutputStandard o) {
			float time = _Time.y * _Speed;
            float2 uv = IN.uv_MainTex;
            
            float3 dh = FlowGrid(uv, time, false);
            #if defined(_DUAL_GRID)
				dh = (dh + FlowGrid(uv, time, true)) * 0.5;
			#endif
            
			fixed4 c = dh.z * dh.z * _Color;
            
			o.Albedo = c.rgb;
			o.Normal = normalize(float3(-dh.xy, 1));
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}