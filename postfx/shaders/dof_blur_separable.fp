varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;

uniform mediump vec4 focus_params; // focus_distance, focus_range, max_blur, near_strength
uniform mediump vec4 blur_params;  // 1/half_width, 1/half_height, unused, unused
uniform mediump vec4 blur_direction; // x, y = axis selection

// Separable blur pass: runs once per axis (blur_direction set externally), gathering along that line with CoC-aware weights.
void main()
{
    mediump vec4 center = texture2D(tex0, var_texcoord0);
    mediump float radius = abs(center.a) * focus_params.z * 6.0;
    mediump vec2 direction = normalize(vec2(blur_direction.x, blur_direction.y));
    mediump vec2 texel = blur_params.xy;
    if (direction.x == 0.0 && direction.y == 0.0) {
        direction = vec2(1.0, 0.0);
    }
    mediump vec2 offset_dir = direction * texel;

    mediump vec3 color = center.rgb;
    mediump float weight = 1.0;

    for (int i = 1; i <= 6; ++i) {
        mediump float step = float(i);
        mediump vec2 offset = offset_dir * step * (1.0 + radius);
        mediump vec4 sample0 = texture2D(tex0, var_texcoord0 + offset);
        mediump vec4 sample1 = texture2D(tex0, var_texcoord0 - offset);
        mediump float w0 = max(0.0, 1.0 - abs(sample0.a - center.a));
        mediump float w1 = max(0.0, 1.0 - abs(sample1.a - center.a));
        w0 += abs(sample0.a);
        w1 += abs(sample1.a);
        if (sample0.a * center.a < 0.0) {
            w0 *= 0.25;
        }
        if (sample1.a * center.a < 0.0) {
            w1 *= 0.25;
        }
        color += sample0.rgb * w0;
        color += sample1.rgb * w1;
        weight += w0 + w1;
    }

    gl_FragColor = vec4(color / weight, center.a);
}
