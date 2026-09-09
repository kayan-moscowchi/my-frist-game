shader_type canvas_item;

uniform float roundness : hint_range(0.1, 1.0) = 0.85;
uniform float highlight_power : hint_range(4.0, 64.0) = 14.0;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    float v = UV.y;
    
    float ny = (v - 0.5) * 2.0;
    float nz = sqrt(max(0.0, 1.0 - ny * ny * roundness));
    
    vec3 light_dir = normalize(vec3(-0.4, -0.7, 0.7));
    vec3 normal = normalize(vec3(0.0, ny, nz));

    float diff = clamp(dot(normal, light_dir), 0.25, 1.15);
    
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_vector = normalize(light_dir + view_dir);
    float spec = pow(max(0.0, dot(normal, half_vector)), highlight_power) * specular_strength;

    vec4 base_col = COLOR;
    vec3 final_rgb = (base_col.rgb * diff) + vec3(spec);
    
    COLOR = vec4(final_rgb, base_col.a);
}
