varying highp vec2 outTexCoor;

uniform sampler2D imageTexture;
uniform lowp float intensity;

const mediump vec3 LUMINANCE_FACTOR = vec3(0.2125, 0.7154, 0.0721);

void main()
{
    highp vec4 sampleColor = texture2D(imageTexture, outTexCoor);
    lowp float luminance = dot(sampleColor.rgb, LUMINANCE_FACTOR);
    gl_FragColor = vec4(mix(vec3(luminance), sampleColor.rgb, 1.0 - intensity), 1.0);
}
