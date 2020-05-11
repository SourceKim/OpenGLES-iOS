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

@end
