Shader "Custom/DistortionFlow" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
        [NoScaleOffset] _FlowMap ("Flow (RG, A noise)", 2D) = "black" {} //This property relates to our flow map.
        //It doesn't require a separate UV tiling and offset so NoScaleOffset.
		//[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
		[NoScaleOffset] _DerivHeightMap ("Deriv (AG) Height (B)", 2D) = "black" {} //Same as the normal map but contains the height
		//derivatives in the X and Y dimensions. Though the height of waves can't go over 45 degrees because the derivative of that
		//is 1.
		_UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
		_Tiling ("Tiling", Float) = 1
		_Speed ("Speed", Float) = 1
		_FlowStrength ("Flow Strength", Float) = 1
		_FlowOffset ("Flow Offset", Float) = 0
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
        
        #include "FlowUV.cginc" //Making a texture flow like water is a generic idea that
        //can be applied to any texture.
        //The very basic is making the texture move like it's a floor motor walkway.
        
		sampler2D _MainTex, _FlowMap, _DerivHeightMap; //_NormalMap;
        //Making real water flow is easier with a flowmap instead of going in on insane maps.
        float _UJump, _VJump, _Tiling, _Speed, _FlowStrength, _FlowOffset;

		struct Input {
			float2 uv_MainTex;
		};
		
		float _HeightScale, _HeightScaleModulated;
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		
		float3 UnpackDerivativeHeight (float4 textureData) {
			float3 dh = textureData.agb;
			dh.xy = dh.xy * 2 - 1;
			return dh;
		}
		
		void surf (Input IN, inout SurfaceOutputStandard o) {
			//float2 flowVector = tex2D(_FlowMap, IN.uv_MainTex).rg * 2 - 1; //The noise from our FlowMap was expressed as rg.
            //The vector's U component in the R channel and the V in the green channel. So we use the RG of Flowmap here to discover
            //which vector that the map is pointing to.
            //flowVector *= _FlowStrength;
			float3 flow = tex2D(_FlowMap, IN.uv_MainTex).rgb;
			flow.xy = flow.xy * 2 - 1;
			flow *= _FlowStrength;
			
			float noise = tex2D(_FlowMap, IN.uv_MainTex).a; //the texture is sampled twice but the shader compiler 
			//will optimize that into a single texture.
			float time = _Time.y * _Speed + noise; //Instead of hard taking time now we mix it with the albedo noise on the flowmap.png
            float2 jump = float2(_UJump, _VJump);
			
			float3 uvwA = FlowUVW(
				IN.uv_MainTex, flow.xy, jump,
				_FlowOffset, _Tiling, time, false); //Invocation of FlowUV.cginc's FlowUV function
            float3 uvwB = FlowUVW(IN.uv_MainTex, flow.xy, jump, 
				_FlowOffset, _Tiling, time, true);
			
			//We can no longer use UnpackNormal because we aren't using an ordinary normal anymore.
			/*
			float3 normalA = UnpackNormal(tex2D(_NormalMap, uvwA.xy)) * uvwA.z;
			float3 normalB = UnpackNormal(tex2D(_NormalMap, uvwB.xy)) * uvwB.z;
			o.Normal = normalize(normalA + normalB); //Use their combined surface normal as the final result.
			*/
			
			float finalHeightScale = flow.z * _HeightScaleModulated + _HeightScale;
			
			float3 dhA = UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwA.xy)) * (uvwA.z * finalHeightScale);
			float3 dhB = UnpackDerivativeHeight(tex2D(_DerivHeightMap, uvwB.xy)) * (uvwB.z * finalHeightScale);
			o.Normal = normalize(float3(-(dhA.xy + dhB.xy), 1));
			
			fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
			fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;
			
			fixed4 c = (texA + texB) * _Color;
			
			o.Albedo = c.rgb;
			//o.Albedo = pow(dhA.z + dhB.z, 2);
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}

	FallBack "Diffuse"
}