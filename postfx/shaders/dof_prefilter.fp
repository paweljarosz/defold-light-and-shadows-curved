varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0; // scene color
uniform lowp sampler2D tex1; // scene depth

uniform mediump vec4 focus_params; // focus_distance, focus_range, max_blur, near_strength
uniform mediump vec4 misc_params;  // far_strength, unused
uniform mediump vec4 depth_params; // near, far, unused, unused
uniform mediump vec4 texel_size;   // 1/width, 1/height, width, height

mediump float linearize_depth(mediump float depth, mediump float near_plane, mediump float far_plane)
{
    mediump float ndc = depth * 2.0 - 1.0;
    return (2.0 * near_plane * far_plane) / (far_plane + near_plane - ndc * (far_plane - near_plane));
}

void main()
{
    mediump vec2 texel = texel_size.xy;
    lowp vec3 c0 = texture2D(tex0, var_texcoord0).rgb;
    lowp vec3 c1 = texture2D(tex0, var_texcoord0 + vec2(texel.x, 0.0)).rgb;
    lowp vec3 c2 = texture2D(tex0, var_texcoord0 + vec2(0.0, texel.y)).rgb;
    lowp vec3 c3 = texture2D(tex0, var_texcoord0 + texel).rgb;
    lowp vec3 color = (c0 + c1 + c2 + c3) * 0.25;

    mediump float depth = texture2D(tex1, var_texcoord0).r;
    mediump float linear_depth = linearize_depth(depth, depth_params.x, depth_params.y);
    mediump float dist = linear_depth - focus_params.x;
    mediump float coc = dist / max(0.0001, focus_params.y);
    coc = clamp(coc, -1.0, 1.0);
    if (coc < 0.0) {
        coc *= focus_params.w;
    } else {
        coc *= misc_params.x;
    }
    coc = clamp(coc, -1.0, 1.0);
    gl_FragColor = vec4(color, coc);
}
