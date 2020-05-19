uniform sampler2D lumaTexture;
uniform sampler2D chromaTexture;

uniform highp mat3 YUV_To_RGB_Matrix;
uniform highp vec3 YUV_Translation;

varying highp vec2 outTexCoor;

void main() {
    
    highp vec3 yuv, rgb;
    
    yuv.r = texture2D(lumaTexture, outTexCoor).r;
    yuv.gb = texture2D(chromaTexture, outTexCoor).ra; // 注意，是 ra
    
    rgb = YUV_To_RGB_Matrix * (yuv + YUV_Translation);
    
    gl_FragColor = vec4(rgb, 1.0);
}
