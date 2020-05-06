////  TriangleView.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/6.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "TriangleView.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>

@implementation TriangleView {
    
    GLuint _glProgram;
    GLuint RBO, FBO;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        EAGLContext *ctx1 = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES2];
        [EAGLContext setCurrentContext: ctx1];
        EAGLContext *ctx = EAGLContext.currentContext;
        NSLog(@"Current ctx: %@", ctx);
        
        
        [self glLayer].opaque = true;
        [self glLayer].frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        [self glLayer].drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking: @(false),
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
        };
        
        glGenRenderbuffers(1, &RBO);
        glBindRenderbuffer(GL_RENDERBUFFER, RBO);
        [ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: [self glLayer]];
        
        glGenFramebuffers(1, &FBO);
        glBindFramebuffer(GL_FRAMEBUFFER, FBO);
        
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, RBO);
        
        // shaders
        NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"passthrough" ofType: @"vsh"];
        NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"passthrough" ofType: @"fsh"];
        GLuint vertex = [self createShader: vertexPath type: GL_VERTEX_SHADER];
        GLuint fragment = [self createShader: fragmentPath type: GL_FRAGMENT_SHADER];
        
        
        _glProgram = glCreateProgram();
        
        glAttachShader(_glProgram, vertex);
        glAttachShader(_glProgram, fragment);
        
        glLinkProgram(_glProgram);
        
        GLint linkStatus;
        glGetProgramiv(_glProgram, GL_LINK_STATUS, &linkStatus);
        
        if (linkStatus == GL_FALSE) {
            
            GLsizei len;
            glGetProgramiv(_glProgram, GL_INFO_LOG_LENGTH, &len);
            
            GLchar *log = (GLchar *)malloc(sizeof(GLchar) * len);
            glGetProgramInfoLog(_glProgram, len, NULL, log);
            
            NSLog(@"Link error, err - %s", log);
        }
        
        glDeleteShader(vertex);
        glDeleteShader(fragment);
        
        glUseProgram(_glProgram);
        
        [self render];
    }
    return self;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (CAEAGLLayer *)glLayer {
    return (CAEAGLLayer *)self.layer;
}

- (GLuint)createShader: (NSString *)path type: (GLenum)type {
    
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

- (void)render {
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.bounds.size.width, self.bounds.size.height);
    
     const GLfloat vertices[] = {
        0.0f,  0.5f, 0.0f,
        -0.5f, -0.5f, 0.0f,
        0.5f,  -0.5f, 0.0f };
    
    static const GLfloat color_data[] = {
        1, 0, 0,
        1, 0, 0,
        1, 0, 0,
    };
    
    GLuint position = glGetAttribLocation(_glProgram, "position");
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(position);
    
    GLuint color = glGetAttribLocation(_glProgram, "vColor");
    glVertexAttribPointer(color, 3, GL_FLOAT, GL_FALSE, 0, color_data);
    glEnableVertexAttribArray(color);
    
    glDrawArrays(GL_TRIANGLES, 0, 3);
    
    [[EAGLContext currentContext] presentRenderbuffer: GL_RENDERBUFFER];
}

@end
