Shader "Custom/Waves" {
	//When making bigger waves we can't get away with pushing normals around using samples from a noise map. 
    //We'll have to manipulate legitimate vertex data using (in my case) sine curves.
    Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
        //_Amplitude ("Amplitude", Float) = 1 //default amplitude of a sine wave is 1 but we don't need to limit ourselves like that.
        
        _WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (1,0,0.5,10) //So this is the big one, we are moving from
        //a single wave to multiple waves. The commented out sections below are relevant for information.
        _WaveB ("Wave B", Vector) = (0,1,0.25,20)
        _WaveC ("Wave C", Vector) = (1,1,0.15,10)
        //_Steepness ("Steepness", Range(0, 1)) = 0.5//We are trading amplitude out for steepness. There's a relation
        //between wave amplitude and wavelength but it requires two variables we don't know: (e^kb)/k where b 
        //has to do with surface pressure.
        //We'll pretend we have the final result of e^kb which is represented by Steepness. 
        //_Wavelength ("Wavelength", Float) = 10
        //_Speed ("Speed", Float) = 1 //Phase speed. Moves the wave using the time offset kct. k is wave number, c is speed, t is time.
        //_Direction ("Direction (2D)", Vector) = (1,0,0,0)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
        
        // -vertex:vert indicates that the surface shader (surf) should use the vertex function.
        // -adddshadow instructs Unity to create a separate shadow caster pass for our shader that also uses our vertex
        //displacement function.
		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows vertex:vert addshadow
		#pragma target 3.0

		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
        float4 _WaveA, _WaveB, _WaveC; //exchanging the old individual properties directly below for 4 floats stored in WaveA
        /*
        float _Steepness, _Wavelength; //, _Speed; //, _Amplitude;
        float2 _Direction; //We are now moving things in more than just the x direction. This direction vector purely 
        //indicates a direction so D of both types = 1.
        */
        
        float3 GerstnerWave (float4 wave, float3 p, inout float3 tangent, inout float3 binormal) {
            
            float steepness = wave.z;
		    float wavelength = wave.w;
            
            float k = 2 * UNITY_PI / wavelength; //k is the wave number which can be used as the shader property
            //to skip the division we do here for optimization, but we're sticking with the more recognizable wavelength.
            //The wave number is the number of cycles in a section of wave of length (in our case) x.
            //It's not the frequency, though it is strongly related.
            
            float c = sqrt(9.8 / k); //Speed (the former shader property) is solved here. As a shader property it
            //was an arbitrary assigned value. In reality the speed of a water wave is sqrt(gravity/k)
            
            float2 d = normalize(wave.xy); //No matter how high we set _Direction we want it to be some unit of 1.
            //Because it only indicates direction and no further.
            
            /*
            To make the wave move in the positive direction we have to subtract the kct formula (outlined at the _Speed shader property)
            from kx. Therefore: p.y = sin(kx-kct) = sin(k(x-ct)). This function will be summarized with the variable: f.
            
            The _Speed property has been replaced with c which IS speed but is now dependent on gravity instead of being
            arbitrarily set by the user.
			
            _Direction is now being worked in here. With the introduction of _Direction, x's strength is modulated by 
            the x value of d (set above). Changing f = k(x-ct) into f = k(d.x(x)-ct).
            But z now also plays a role therefore f = k(d.x(x) + d.z(z) - ct)
            But the section "d.x(x) + d.z(z)" is just a dot product. dot(d,p.xz)
            */
            float f = k * (dot(d, p.xz) - c * _Time.y);
            float a = steepness / k; //The amplitude has been pushed here. This is where our fake (e^kb)/k truly happens.
            
            /*
            Sine waves do not match the shape of real waves. The Stokes wave function, while complex, correctly models wave motion
            but the Gerstner function is often used instead.
            Each surface point move along a circle with a fixed anchor point. As the crest of the wave approaches, the point moves
            toward it. After the crest passes it slides back and the next crest comes along.
            We turn our sine wave into a circle with P = (acos(f),asin(f)). But that turns our whole wave into a circle.
            We anchor each point to its original x coordinate by adding x. Therefore P = (x + acos(f),asin(f)) 
            
            We also have to adjust the offsets of p.x and p.z to align with the wave direction so here it comes.
            */
            /*
            //We are now leaving the x and z parts out of the result which in turn means we take it out of the derivatives.
            //because x and z accumulate offsets but we will make the tangents accumulate offsets instead.
            p.x += d.x * (a * cos(f));
            p.y = a * sin(f);
            p.z += d.y * (a * cos(f));
            */
            
            //I am aware that Gerstner functions usually use sine for x and cos for y but I was already dug in at this point
            //And the only difference between sine and cos is a shift in the wave's period by a quarter, right?
            //
            //Right?
            
            /*
            If we don't find the surface tangent vector of our sine wave our light reflection won't acknowledge our plane's movement.
            The surface tangent vector is tangent = (derivative of x, derivative of y).
            the derivative of x on its own is a neat 1 because x is [x co-ordinate] (which is what we have for now, we'll be changing that)
            and for a flat surface that makes a neat (1,0).
            
            But we are not using a flat surface.
            
            The derivative of the sin(f) is cosine so cos(f) where f is our function.
            The derivative of our original function "asin(f)" where f = k(x-ct) is f'acos(f) and f' = k therefore kacos(f)
            derivatives are a bit too complex to explain how to do them here.
            
            With the application of the Gerstner function our new x coordinate = x + acos(f)
            the derivative of cos is negative sine and we know what x'(= 1) and f'(= k) are from above.
            
            There's been a new change. a = _Steepness/k changes our derivatives. Thankfully they simplify neatly.
            P.x = x + (s/k)cos(f) -> T.x = 1-s(sin(f))
            P.y = (s/k)sin(f) -> T.y = s(cos(f))
            
            With the addition of direction vectors, our tangents (and as a result our normals) need to change to match.
            The partial derivative of f in the x dimension is kD.x. f'(_Steepness)sin(f) then becomes d.x^2(_Steepness)sin(f)
            (don't include the dot product, remember, we are only working in the x direction for this segment)
            In the case of our tangent's x and y values this just means we multiply with d.x one more time.
            We also have to create a derivative of z. (d.y is the z direction. Because we only have two coordinates we are just
            using d.y as our z direction)
            
            Because we are leaving out p.x and such above we no longer need to have the x + part of the function which in turn means
            we don't need to have the 1 part of the derivative (1 - [the rest of the function])
            */
            
            //Calculate the normals for light reflection. tangent and binormal are inout variables, so they'll be returned
            //as necessary as well.
            //These normals are not necessary for the Gerstner formula but are necessary for light reflections.
            tangent += float3(
                -d.x * d.x * (steepness * sin(f)), //derivative of x
                d.x * (steepness * cos(f)), //derivative of y 
                -d.x * d.y * (steepness * sin(f)) //derivative of z
            );
            //And now we need to account for the tangent created by z. So we need a second normal.
            //The difference is the samea s before but we multiply by d.z (although due to the way things are named
            //it's called d.y)
            binormal += float3(
				-d.x * d.y * (steepness * sin(f)),
				d.y * (steepness * cos(f)),
				-d.y * d.y * (steepness * sin(f))
			);
            
            //Return the position of the point that is being gerstner waved.
            //It's p.x, p.y, and p.z commented out above.
            return float3 (
                d.x * (a * cos(f)),
				a * sin(f),
				d.y * (a * cos(f))
			);
        }
        
		void vert(inout appdata_full vertexData) {
            //P is the final position of our vertex. We'll be moving this on a sine wave so expect it to get pushed around a bit.
            //x is the x coordinate and y will be changing based on x so it goes from y = [y-coordinate] into y = sin(x)
            //that will make a very basic wave, it won't stay like that for long, but the underlying principle is the same. We'll be making
            //different motions along x and z.
            float3 gridPoint = vertexData.vertex.xyz; //gridPoint and p are the same thing.
            float3 tangent = float3(1, 0, 0);
			float3 binormal = float3(0, 0, 1);
			float3 p = gridPoint;
			p += GerstnerWave(_WaveA, gridPoint, tangent, binormal);
            p += GerstnerWave(_WaveB, gridPoint, tangent, binormal);
            p += GerstnerWave(_WaveC, gridPoint, tangent, binormal);
            //The normal vector is the cross product of both tangent vectors x and y. Z isn't used right now
            //because our wave is currently constant in the Z dimension.
            float3 normal = normalize(cross(binormal, tangent));
			vertexData.vertex.xyz = p;
            vertexData.normal = normal;
        }
        
		void surf (Input IN, inout SurfaceOutputStandard o) {
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}