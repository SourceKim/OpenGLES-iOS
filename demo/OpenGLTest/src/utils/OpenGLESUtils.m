//
//  OpenGLESUtils.m
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/7.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "OpenGLESUtils.h"

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

@end
