#[compute]
#version 450

// Invocation in the (x, y, z) dimension
// c.f: Godot documentation https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html#create-a-local-renderingdevice
// This is how many invocations to be used in each workgroup.
// Workgroups run in parallel to each other.
// While running one workgroup, you cannot access information in another workgroup.
// However, invocations in the same workgroup can have some limited access to other invocations. 
// This about workgroups and invocations as one giant nested for loop. 
// NOTE: For now, remember we will be running 2 * 1 * 1 = 2 invocations per workgroup.
// layout(local_size_x = 2, local_size_y = 1, local_size_z = 1) in; 

// NOTE: Now, we want to use an RGBA 16 bit image, so we will use 8 * 8 * 1 instead.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// A binding to the buffer we create in our script.
// Here we provide informations about the memory the buffer will have access to.
// The layout property allows us to tell the shader where to look from the buffer.
// We will need to match the set and binding properties from the CPU side later.

// NOTE: The **restrict** keyword tells the shader that this buffer is only going to be accessed from one place in this shader. This lets the shader compiler optimize the code. 
// Always use restrict when you can.

// NOTE: This is an unsized buffer, which means it can be any size. We need to be careful
// not to read from an index larger than the size of the buffer.
// layout(set = 0, binding = 0, std430) restrict buffer MyDataBuffer {
//	float data[];
//}
//my_data_buffer;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

vec2 a = vec2(-0.5, 0.5);
vec2 b = vec2(1.0, 1.0);
vec2 c = vec2(0.5, -0.5);
vec2 d = vec2(-0.5, -0.5);

// our push constants
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;

// The code we want to execute each invocation.
void main(){
	// gl_GlobalInvocationID uniquely identifies this invocation across all work groups.
	vec2 uv = vec2(gl_GlobalInvocationID.xy);
	ivec2 uvCoord = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// If it's one of the vertices, draw in black
	bool shape = uv.x < b.x && uv.x > -b.x && uv.y < b.y && uv.y > -b.y;
	vec4 color = imageLoad(color_image, uvCoord);

	// If not, clear the screen to magenta
	color = shape ? vec4(0, 0, 0, 1) : vec4(size.x/uv.x, size.y/uv.y, 0, 1); 
	imageStore(color_image, uvCoord, color);
}

// NOTE: Next, we need to create a custom RenderingDevice on the CPU side.
// (See the GDScript code)
