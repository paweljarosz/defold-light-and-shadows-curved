varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;
uniform mediump vec4 texel_size; // 1/width, 1/height, unused, unused

// Simple 5-tap cross blur in screen space; ignores depth/CoC and just softens the whole frame.
void main()
{
    mediump vec2 texel = texel_size.xy;
    lowp vec3 color = texture2D(tex0, var_texcoord0).rgb * 0.4;
    color += texture2D(tex0, var_texcoord0 + vec2(texel.x, 0.0)).rgb * 0.15;
    color += texture2D(tex0, var_texcoord0 - vec2(texel.x, 0.0)).rgb * 0.15;
    color += texture2D(tex0, var_texcoord0 + vec2(0.0, texel.y)).rgb * 0.15;
    color += texture2D(tex0, var_texcoord0 - vec2(0.0, texel.y)).rgb * 0.15;
    gl_FragColor = vec4(color, 1.0);
}
