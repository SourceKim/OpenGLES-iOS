////  PaintBoardViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/27.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "PaintBoardViewController.h"

#import "OpenGLESUtils.h"

#import "PaintBoardTouchManager.h"

@interface PaintBoardViewController ()<PaintBoardTouchManagerDelegate>

@end

@implementation PaintBoardViewController {
    
    PaintBoardTouchManager *_touchManager;
    
    CGFloat _pointSize;
    
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
    
    float *_vertices;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _pointSize = 5;
    
    _vertices = malloc(sizeof(float) * 256);
    
    _touchManager = [[PaintBoardTouchManager alloc] initWithView: self.view];
    _touchManager.delegate = self;
    
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self createBuffers];
    [self setupVBO];
    
    [self clearFBO: self.view.bounds.size];
    
    [self render: @[ @(CGPointMake(0.5, 0)) ] ];
    [self present];

}

#pragma mark - Response - Touches & Touch Manager

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_touchManager onTouchBegan: touches withEvent: event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_touchManager onTouchMovedOrEnded: touches withEvent: event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_touchManager onTouchMovedOrEnded: touches withEvent: event];
}

- (void)onPointsOut:(NSArray<NSValue *> *)points {
    [self render: points];
    [self present];
}

- (CGFloat)currentPointSize {
    return _pointSize;
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
        kEAGLDrawablePropertyRetainedBacking: @(true),
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
    
//    glEnable(GL_BLEND);
//    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

- (void)clearFBO: (CGSize)size {

    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)setupVBO {
    glGenBuffers(1, &_VBO);
}

- (void)render: (NSArray<NSValue *> *)points {
    
    NSUInteger verticesCount = points.count;
    
    for (int i=0; i<verticesCount; i++) {
        CGPoint point = points[i].CGPointValue;
        _vertices[i * 2] = point.x;
        _vertices[i * 2 + 1] = point.y;
    }
    
    // 0. Bind the FBO
//    [self clearFBO: self.view.bounds.size];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    
    glUseProgram(_program);
    
    glUniform3f(_colorUniformLoc, 1, 1, 1); // 物体颜色
    
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    glBufferData(GL_ARRAY_BUFFER, verticesCount * 2 * sizeof(float), _vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(_positionLoc);
    glVertexAttribPointer(_positionLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    glDrawArrays(GL_POINTS, 0, (int)verticesCount);
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

@end
