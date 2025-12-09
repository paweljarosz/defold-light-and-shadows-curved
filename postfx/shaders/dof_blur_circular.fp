varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;

uniform mediump vec4 focus_params; // focus_distance, focus_range, max_blur, near_strength
uniform mediump vec4 blur_params;  // 1/half_width, 1/half_height, unused, unused

// 8-direction circular gather with an extra inner ring to approximate round bokeh; radius scales from CoC alpha channel.
const int SAMPLE_COUNT = 8;
const mediump vec2 OFFSETS[SAMPLE_COUNT] = vec2[SAMPLE_COUNT](
    vec2(1.0, 0.0),
    vec2(-1.0, 0.0),
    vec2(0.0, 1.0),
    vec2(0.0, -1.0),
    vec2(0.7071, 0.7071),
    vec2(-0.7071, 0.7071),
    vec2(0.7071, -0.7071),
    vec2(-0.7071, -0.7071)
);

void main()
{
    mediump vec4 center = texture2D(tex0, var_texcoord0);
    mediump float radius = abs(center.a) * focus_params.z * 6.0;
    mediump vec2 texel = blur_params.xy;
    mediump vec2 scaled_texel = texel * (1.0 + radius);

    mediump vec3 color = center.rgb;
    mediump float weight = 1.0;

    for (int i = 0; i < SAMPLE_COUNT; ++i) {
        mediump vec2 dir = OFFSETS[i];
        mediump vec4 sample_color = texture2D(tex0, var_texcoord0 + dir * scaled_texel);
        mediump float w = max(0.0, 1.0 - abs(sample_color.a - center.a));
        w += abs(sample_color.a);
        color += sample_color.rgb * w;
        weight += w;
    }

    // Inner ring for smoother circles
    mediump vec2 inner_texel = texel * (0.5 + radius * 0.5);
    for (int i = 0; i < SAMPLE_COUNT; ++i) {
        mediump vec2 dir = OFFSETS[i];
        mediump vec4 sample_color = texture2D(tex0, var_texcoord0 + dir * inner_texel);
        mediump float w = max(0.0, 1.0 - abs(sample_color.a - center.a)) * 0.5;
        w += abs(sample_color.a) * 0.5;
        color += sample_color.rgb * w;
        weight += w;
    }

    gl_FragColor = vec4(color / weight, center.a);
}
