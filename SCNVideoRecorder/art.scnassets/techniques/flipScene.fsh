varying lowp vec2 texCoordVarying;
uniform sampler2D textureUnit;

void main()
{
    lowp vec2 uv = texCoordVarying;
    uv.y = 1. - uv.y;
    gl_FragColor = texture2D(textureUnit, uv);
}
