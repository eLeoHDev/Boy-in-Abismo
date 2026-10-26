shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float blur_amount : hint_range(0.0, 16.0) = 0.0;
uniform int blur_samples : hint_range(1, 32) = 12;

void fragment() {
    vec4 color;

    if (blur_amount < 0.01) {
        color = texture(screen_texture, SCREEN_UV);
    } else {
        color = vec4(0.0);
        float radius = blur_amount * SCREEN_PIXEL_SIZE.x;
        for (int i = 0; i < blur_samples; i++) {
            float angle = float(i) * 6.2831853 / float(blur_samples);
            vec2 offset = vec2(cos(angle), sin(angle)) * radius;
            color += texture(screen_texture, SCREEN_UV + offset);
        }
        color /= float(blur_samples);
    }

    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(vec3(gray), color.rgb, saturation);
    COLOR = color;
}