////  PaintBoardViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/27.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "PaintBoardViewController.h"

#import "OpenGLESUtils.h"

#import "PaintBoardTouchManager.h"

#define MAX_POINT_COUNT 512

@interface PaintBoardViewController ()<PaintBoardTouchManagerDelegate>

@end

@implementation PaintBoardViewController {
    
    PaintBoardTouchManager *_touchManager;
    
    CGFloat _pointSize;
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    CGSize _drawableSize;

    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _VBO;
    
    // Programs
    GLuint _program;
    
    // Texture Buffer Index
    GLuint _brushTextureBufferIndex;
    
    // Texture Id
    GLuint _brushTextureId0;
    GLuint _brushTextureId1;
    GLuint _currentBrushTextureId;
    
    // Attributes 的 location
    GLuint _positionLoc;
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _pointSizeUniformLoc;
    GLuint _colorUniformLoc;
    GLuint _brushTextureUniformLoc;
    
    // The vertices of points
    float *_vertices;
    
    // Brush color
    UIColor *_brushColor;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _pointSize = 80;
    _brushColor = UIColor.whiteColor;
    
    _brushTextureBufferIndex = 5;
    
    _vertices = malloc(sizeof(float) * MAX_POINT_COUNT * 2);
    
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
    [self loadBrushes];
    
    _currentBrushTextureId = _brushTextureId0;
    
    [self clearFBO: _drawableSize];
    
    [self render: @[]];
    [self present];

}

- (void)dealloc {
    free(_vertices);
    glDeleteBuffers(1, &_RBO);
    glDeleteBuffers(1, &_FBO);
    glDeleteBuffers(1, &_VBO);
    glDeleteProgram(_program);
    glDeleteTextures(1, &_brushTextureId0);
    glDeleteTextures(1, &_brushTextureId1);
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

- (CGFloat)screenScale {
    return [UIScreen mainScreen].scale;
}

- (IBAction)onRoundBtnClicked:(id)sender {
    _currentBrushTextureId = _brushTextureId0;
}

- (IBAction)onGlowBtnClicked:(id)sender {
    _currentBrushTextureId = _brushTextureId1;
}

- (IBAction)onModeChanged:(id)sender {
    UISegmentedControl *seg = sender;
    if (seg.selectedSegmentIndex == 0) {
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        glBlendFunc(GL_ZERO, GL_ONE_MINUS_SRC_ALPHA);
    }
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
        kEAGLDrawablePropertyRetainedBacking: @(true), // Important !!!
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
    };
    _glLayer.frame = self.view.bounds;
    _glLayer.contentsScale = UIScreen.mainScreen.scale;
    [self.view.layer insertSublayer: _glLayer atIndex: 0];
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
    
    _pointSizeUniformLoc = glGetUniformLocation(program, "pointSize");
    _colorUniformLoc = glGetUniformLocation(program, "color");
    _brushTextureUniformLoc = glGetUniformLocation(program, "brushTexture");
    
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
    
    GLint w, h;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &w);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &h);
    _drawableSize = CGSizeMake(w, h);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

- (void)loadBrushes {
    _brushTextureId0 = [OpenGLESUtils loadImageTexture: [UIImage imageNamed: @"RoundBrush.png"]];
    _brushTextureId1 = [OpenGLESUtils loadImageTexture: [UIImage imageNamed: @"GlowBrush.png"]];
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
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    
    glUseProgram(_program);
    
    glUniform1f(_pointSizeUniformLoc, _pointSize);
    CGFloat R, G, B;
    [_brushColor getRed: &R green: &G blue: &B alpha: NULL];
    glUniform3f(_colorUniformLoc, R, G, B);
    
    glActiveTexture(GL_TEXTURE0 + _brushTextureBufferIndex);
    glBindTexture(GL_TEXTURE_2D, _currentBrushTextureId);
    glUniform1i(_brushTextureUniformLoc, _brushTextureBufferIndex);
    
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
