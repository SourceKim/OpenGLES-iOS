////  PaintBoardViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/27.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "PaintBoardViewController.h"

#import "OpenGLESUtils.h"

@interface PaintBoardViewController ()

@end

@implementation PaintBoardViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _VBO;
    
    // Programs
    GLuint _program;
    
    // Attributes 的 location
    GLuint _positionLoc;
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _colorUniformLoc;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self createBuffers];
    [self setupVBO];
    
    [self render];
    
}

#pragma mark - OpenGL ES

- (void)setupContext {
    
    _ctx = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext: _ctx];

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

- (void)setupPrograms {
    _program = [self createProgram];
}

- (GLuint)createProgram {
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"PaintBoard" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"PaintBoard" ofType: @"fsh"];
    
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    
    GLuint program = [OpenGLESUtils linkProgram: vertex
                                 fragmentShader: fragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(program, "position");
    
    _colorUniformLoc = glGetUniformLocation(program, "color");
    
    return program;
}

- (void)createBuffers {
    
    // 创建 RBO Render Buffer Object
    glGenRenderbuffers(1, &_RBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: _glLayer];
    
    // Then, FBOs..
    
    // 创建 FBO Frame Buffer Object
    glGenFramebuffers(1, &_FBO);
    
    // 配置 FBO - Render FrameBuffer：
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO); // 使用 FBO，下面的激活 & 绑定操作都会对应到这个 FrameBuffer
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _RBO); // 附着 渲染的颜色 RBO
}

- (void)clearFBO: (CGSize)size {

    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)setupVBO {
    glGenBuffers(1, &_VBO);
}

- (void)render: (CGSize)clearSize
        points: (NSArray<NSValue *> *)points {
    
    NSUInteger verticesCount = points.count;
    float *vertices = malloc(sizeof(float) * verticesCount * 2);
    
    for (int i=0; i<verticesCount; i++) {
        CGPoint point = points[i].CGPointValue;
        vertices[i * 2] = point.x;
        vertices[i * 2 + 1] = point.y;
    }
    
    // 0. Bind the FBO & Clear the FBO
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    
    glUseProgram(_program);
    
    glUniform3f(_colorUniformLoc, 1, 1, 1); // 物体颜色
    
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, verticesCount, vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(_positionLoc);
    glVertexAttribPointer(_positionLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    glDrawArrays(GL_POINTS, 0, (int)verticesCount);
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

- (void)render {
//    int depth;
//    glGetIntegerv(GL_DEPTH_BITS, &depth);
//    NSLog(@"%i bits depth", depth);
    [self render: _glLayer.bounds.size points: @[@(CGPointMake(0.5, 0.5))]];
    [self present];
}

@end
