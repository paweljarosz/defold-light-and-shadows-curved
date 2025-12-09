varying mediump vec2 var_texcoord0;

uniform lowp sampler2D tex0;

void main()
{
    lowp vec4 color = texture2D(tex0, var_texcoord0);
    if (color.a < 0.2) {
        discard;
    }
    gl_FragColor = vec4(gl_FragCoord.z);
}
