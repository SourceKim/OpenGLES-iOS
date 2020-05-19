////  YUV_To_RGB_Matrices_Vectors.h
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

/*
 YUV 转 RGB 矩阵
 
 Copy from GPUImage/GPUImageVideoCamera.m
 */

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)

// BT.601, which is the standard for SDTV.
const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};


/*
 YUV 转 RGB 的变换 Translation
 
 Inspire by GPUImage
 */

const GLfloat kColorTranslationFullRange[] = {
    0.0, -0.5, -0.5
};

const GLfloat kColorTranslationVideoRange[] = {
    -16.0 / 255.0, -0.5, -0.5
};
