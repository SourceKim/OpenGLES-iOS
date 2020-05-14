//
//  OpenGLESUtils.m
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/7.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "OpenGLESUtils.h"

#import <AVFoundation/AVFoundation.h> // For generating vertices

@implementation OpenGLESUtils

+ (GLuint)createShader: (NSString *)path type: (GLenum)type {
    
    GLuint shader = glCreateShader(type);
    
    NSString *str = [NSString stringWithContentsOfFile: path encoding: NSUTF8StringEncoding error: nil];
    
    const GLchar *glStr = (GLchar *)[str UTF8String];
    glShaderSource(shader, 1, &glStr, NULL);
    
    glCompileShader(shader);
    
    GLint compileStatus;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileStatus);
    
    if (compileStatus == GL_FALSE) {
        
        GLsizei len;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);
        
        GLchar *log = (GLchar *)malloc(sizeof(GLchar) * len);
        glGetShaderInfoLog(shader, len, NULL, log);
        
        NSLog(@"Create shader with path - %@, err - %s", path, log);
        
        return -1;
    }
    
    return shader;
}

+ (GLuint)linkProgram:(GLuint)vertexShader fragmentShader:(GLuint)fragmentShader {
    
    GLuint program;
    
    program = glCreateProgram();
    
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    
    glLinkProgram(program);
    
    GLint linkStatus;
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    
    if (linkStatus == GL_FALSE) {
        
        GLsizei len;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &len);
        
        GLchar *log = (GLchar *)malloc(sizeof(GLchar) * len);
        glGetProgramInfoLog(program, len, NULL, log);
        
        NSLog(@"Link error, err - %s", log);
    }
    
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    
    return program;
}

+ (GLfloat *)generateVertices: (OpenGLFillMode)fillMode
             withDisplayRatio: (GLfloat)displayRatio
                withImageSize: (CGSize)imageSize
             withViewPortSize: (CGSize)viewPortSize {
    
    CGFloat wfactor, hfactor;
    
    CGSize newSize = AVMakeRectWithAspectRatioInsideRect(imageSize,
                                                         CGRectMake(0, 0, viewPortSize.width, viewPortSize.height)).size;
    
    switch (fillMode) {
        case OpenGLFillMode_AspectRatioFit:
            wfactor = newSize.width / viewPortSize.width;
            hfactor = newSize.height / viewPortSize.height;
            break;
        case OpenGLFillMode_AspectRatioFill:
            wfactor = viewPortSize.height / newSize.height;
            hfactor = viewPortSize.width / newSize.width;
            break;
        case OpenGLFillMode_ScaleToFill:
            wfactor = 1;
            hfactor = 1;
            break;
    }
    
    GLfloat vertices[] = {
        -displayRatio * wfactor, -displayRatio * hfactor, 0, // 左下角
        displayRatio * wfactor, -displayRatio * hfactor, 0, // 右下角
        -displayRatio * wfactor, displayRatio * hfactor, 0, // 左上角
        displayRatio * wfactor, displayRatio * hfactor, 0, // 右上角
    };
    
    GLfloat *rtn = malloc(sizeof(GLfloat) * 12);
    memcpy(rtn, vertices, sizeof(GLfloat) * 12);
    
    return rtn;
}

+ (GLuint)loadImageTexture: (UIImage *)image {
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextTranslateCTM(context, 0, height); // 所有内容下移 height
    CGContextScaleCTM(context, 1.0f, -1.0f); // 翻转
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    CGContextDrawImage(context, rect, cgImageRef);
    
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}

+ (void)printMatrix4: (GLKMatrix4)matrix4 {
    NSLog(@"\n"
          @"%.2f  %.2f  %.2f  %.2f \n"
          @"%.2f  %.2f  %.2f  %.2f \n"
          @"%.2f  %.2f  %.2f  %.2f \n"
          @"%.2f  %.2f  %.2f  %.2f \n",
          matrix4.m00, matrix4.m01, matrix4.m02, matrix4.m03,
          matrix4.m10, matrix4.m11, matrix4.m12, matrix4.m13,
          matrix4.m20, matrix4.m21, matrix4.m22, matrix4.m23,
          matrix4.m30, matrix4.m31, matrix4.m32, matrix4.m33);
}

@end
