varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0; // scene color
uniform lowp sampler2D tex1; // blurred color
uniform lowp sampler2D tex2; // depth

uniform mediump vec4 focus_params; // focus_distance, focus_range, max_blur, near_strength
uniform mediump vec4 misc_params;  // far_strength, unused
uniform mediump vec4 depth_params; // near, far, unused, unused
uniform mediump vec4 enable_params; // x: depth-enabled, w: fullscreen blur flag
uniform mediump vec4 tint_control; // intensity, enabled flag
uniform lowp vec4 tint_near;
uniform lowp vec4 tint_focus;
uniform lowp vec4 tint_far;

mediump float linearize_depth(mediump float depth, mediump float near_plane, mediump float far_plane)
{
    mediump float ndc = depth * 2.0 - 1.0;
    return (2.0 * near_plane * far_plane) / (far_plane + near_plane - ndc * (far_plane - near_plane));
}

void main()
{
    lowp vec3 color = texture2D(tex0, var_texcoord0).rgb;
    lowp vec3 blurred = texture2D(tex1, var_texcoord0).rgb;
    if (enable_params.w > 0.5) {
        gl_FragColor = vec4(blurred, 1.0);
        return;
    }
    mediump float depth = texture2D(tex2, var_texcoord0).r;
    mediump float linear_depth = linearize_depth(depth, depth_params.x, depth_params.y);
    mediump float dist = linear_depth - focus_params.x;
    mediump float signed_coc = dist / max(0.0001, focus_params.y);
    signed_coc = clamp(signed_coc, -1.0, 1.0);
    mediump float coc = signed_coc;
    if (coc < 0.0) {
        coc *= focus_params.w;
    } else {
        coc *= misc_params.x;
    }
    coc = clamp(abs(coc), 0.0, 1.0);
    coc *= focus_params.z;
    coc *= enable_params.x;
    lowp vec3 final_color = mix(color, blurred, coc);

    mediump float tint_strength = tint_control.x * tint_control.y;
    if (tint_strength > 0.0) {
        mediump float near_weight = clamp(-signed_coc, 0.0, 1.0);
        mediump float far_weight = clamp(signed_coc, 0.0, 1.0);
        mediump float focus_weight = 1.0 - max(near_weight, far_weight);
        lowp vec3 tint = tint_focus.rgb * focus_weight + tint_near.rgb * near_weight + tint_far.rgb * far_weight;
        final_color = mix(final_color, tint, clamp(tint_strength, 0.0, 1.0));
    }
    gl_FragColor = vec4(final_color, 1.0);
}
