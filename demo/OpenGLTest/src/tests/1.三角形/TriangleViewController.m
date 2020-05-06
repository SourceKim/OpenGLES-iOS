////  TriangleViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/6.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "TriangleViewController.h"

#import "TriangleView.h"

#import "OpenGLESUtils.h"

@interface TriangleViewController ()

@property (nonatomic, strong) TriangleView * triangleView;
@end

@implementation TriangleViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    GLuint _FBO, _RBO;
    
    GLuint _glProgram;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor: [UIColor whiteColor]];
    
    [self setupContext];
    [self setupLayer];
    [self createBuffers];
    [self setupProgram];
    [self draw];
    [self present];
}

- (void)setupContext {
    
    _ctx = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext: _ctx];
    
    NSLog(@"CTX0： %@ - %@", [NSThread currentThread], [EAGLContext currentContext]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"CTX1：%@ - %@", [NSThread currentThread], [EAGLContext currentContext]);
    });
}

- (void)setupLayer {
    
    _glLayer = [CAEAGLLayer layer];
    _glLayer.opaque = true;
    _glLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking: @(false),
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
    };
    _glLayer.frame = self.view.bounds;
    [self.view.layer addSublayer: _glLayer];
}

- (void)createBuffers {
    
    // 创建 Render Buffer Object
    glGenRenderbuffers(1, &_RBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: _glLayer];
    
    // 创建 Frame Buffer Object
    glGenFramebuffers(1, &_FBO);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _RBO);
}

- (void)setupProgram {
    
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"passthrough" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"passthrough" ofType: @"fsh"];
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
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
}

- (void)draw {
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
     const GLfloat vertices[] = {
        0, 0.5, 0,
        -0.5, -0.5, 0,
        0.5, -0.5, 0 };
    
    static const GLfloat color_data[] = {
        1, 0, 0,
        0, 1, 0,
        1, 0, 0,
    };
    
    GLuint position = glGetAttribLocation(_glProgram, "position");
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(position);
    
    GLuint color = glGetAttribLocation(_glProgram, "vColor");
    glVertexAttribPointer(color, 3, GL_FLOAT, GL_FALSE, 0, color_data);
    glEnableVertexAttribArray(color);
    
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

- (void)present {
    
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}


@end
