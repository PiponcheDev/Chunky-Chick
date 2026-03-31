shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec3 night_tint = vec3(0.2, 0.4, 1.0); 
uniform float tint_intensity = 0.5; 
uniform float darkness = 0.6;
uniform float vignette_strength = 0.4;

void fragment() {
    vec4 scene_color = texture(SCREEN_TEXTURE, SCREEN_UV);

    scene_color.rgb *= darkness;
    vec3 tinted = mix(scene_color.rgb, night_tint, tint_intensity);
    float dist = distance(SCREEN_UV, vec2(0.5));
    float vignette = smoothstep(0.8, 0.5, dist);
    tinted *= mix(1.0, 1.0 - vignette_strength, vignette);

    COLOR = vec4(tinted, scene_color.a);
}