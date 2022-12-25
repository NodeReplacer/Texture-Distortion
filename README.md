# Texture-Distortion For Water Effect
Utilizing a process outlined by Alex Vlachos of Valve to animate a texture as if it were water.


https://user-images.githubusercontent.com/80176553/209481883-0aaee988-7ee8-4146-8a0a-8843facdc3cf.mp4

# Distortion Flow
A shader is used to distort the UV coordinates of a texture.
The shader samples from curl noise and uses a Flow Map which holds 2D vectors in its R and G channels. The R channel holds U values while the G hold V coordinates. This causes distortion and as we progress along it gets worse and worse. We loop back to the "no distortion" point and then put work into hiding the fact that we are doing so (because a water texture going from "distorted" to "completely still" is very obvious). This process is then looped.

https://user-images.githubusercontent.com/80176553/209481944-8a948311-86fd-4dc0-8bb1-d767f7447c69.mp4

#Waves
Texture animation creates the illusion of moving surfacces, but the mesh is not actually moving.
That's fine for small ripples but cannot create big waves.
To start with: We use multiple sine waves to modify the vertex data of whatever mesh our Waves shader is attached to. This cannot be done with a quad but must use a plane of multiple 10x10 quads. That's our baseline. Of course, waves don't really move like that so we expand this idea.

To continue: We discover that realistic waves are better modelled by something called the Stokes Wave Function which turns out to be excruciatingly complex. Furthermore, it appears that Gerstner Waves are more often used for realtime wave animations. Furthermore, we used to keep the waves in the x direction but need to include the z direction which slightly complicates the waves' shape.

Afterwards: We combine multiple waves. Where before we only had one wave and needed to track only one Direction, Wavelength, and Steepness we now make 4D vectors that are not actually used for direction but instead used to store the information of each waves. Arrays in everything but name.
