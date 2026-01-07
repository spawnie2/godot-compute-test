# Based on https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html#create-a-local-renderingdevice:
# and  	https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html
@tool
class_name Custom_Renderer extends CompositorEffect
var renderingDevice: RenderingDevice
var shader: RID
var pipeline: RID
var shader_file: Resource

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	renderingDevice = RenderingServer.get_rendering_device()	
	# Load glsl shader
	shader_file = load("res://compute_example.glsl")
	shader_file.changed.connect(_check_shader)
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = renderingDevice.shader_create_from_spirv(shader_spirv)
	# Create a compute pipeline 
	pipeline = renderingDevice.compute_pipeline_create(shader)

func _check_shader() -> bool:
	if not renderingDevice:
		return false
	
	# Free the old shader	
	if (shader.is_valid()):
		renderingDevice.free_rid(shader)
		
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = renderingDevice.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		return false
	
	pipeline = renderingDevice.compute_pipeline_create(shader)
	return pipeline.is_valid()
	
# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			renderingDevice.free_rid(shader)
			
func _render_callback(p_effect_callback_type, p_render_data):
	if renderingDevice and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:		
			var buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
			var size = buffers.get_internal_size()
			
			var input_image = buffers.get_color_layer(0)
						
			var x_groups = (size.x - 1) / 8 + 1
			var y_groups = (size.y - 1) / 8 + 1
			var z_groups = 1
			
			var push_constant: PackedFloat32Array = PackedFloat32Array()
			push_constant.push_back(size.x)
			push_constant.push_back(size.y)
			push_constant.push_back(0.0)
			push_constant.push_back(0.0)
			
			if (!shader.is_valid()):
				return false;

			if (shader.is_valid()):
				# Create a uniform to assign the buffer to a rendering device.
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0 # this need to match the "binding" in our shader file
				uniform.add_id(input_image)				
				# The middle parameter needs to match the "set" in our shader file
				var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [ uniform ])
				
				var compute_list := renderingDevice.compute_list_begin()
				renderingDevice.compute_list_bind_compute_pipeline(compute_list, pipeline)
				renderingDevice.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				renderingDevice.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				renderingDevice.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				renderingDevice.compute_list_end()
					 
				# The buffer, pipeline and uniform_set each use a resource ID. (RID)
				# They aren't freed automatically. You are responsible for freeing them using the 
				# RenderingDevice free_rid() method.
