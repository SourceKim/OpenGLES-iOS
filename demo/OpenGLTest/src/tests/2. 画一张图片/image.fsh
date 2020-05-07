varying highp vec2 outTexCoor;

uniform sampler2D tex;

void main()
{
    gl_FragColor = texture2D(tex, outTexCoor);
}
