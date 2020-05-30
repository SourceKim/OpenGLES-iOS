//
//  BlendViewController.m
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/30.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "BlendViewController.h"

#import "OpenGLESUtils.h"

// 左上顶点
static const GLfloat vertices0[] = {
    -1, -0.25, 0, // 左下角
    0.25, -0.25, 0, // 右下角
    -1, 1, 0, // 左上角
    0.25, 1, 0 // 右上角
};

// 右下顶点
static const GLfloat vertices1[] = {
    -0.25, -1, 0, // 左下角
    1, -1, 0, // 右下角
    -0.25, 0.25, 0, // 左上角
    1, 0.25, 0 // 右上角
};

static const GLfloat texCoor[] = {
    0, 0, // 左下角
    1, 0, // 右下角
    0, 1, // 左上角
    1, 1, // 右上角
};

static const GLushort indices[] = {
    0, 1, 2,
    1, 3, 2
};

@interface BlendViewController ()

@end

@implementation BlendViewController {
    
    // Color Images
    UIImage *_img0;
    UIImage *_img1;
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    CGSize _drawableSize;

    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, *_VAOs;
    
    // Programs
    GLuint _program;
    
    // Texture Buffer Index
    GLuint _textureBufferIndex0;
    GLuint _textureBufferIndex1;
    
    // Texture Id
    GLuint _textureId0;
    GLuint _textureId1;
    
    // Attributes 的 location
    GLuint _positionLoc;
    GLuint _texCoorLoc;
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _textureUniformLoc;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _img0 = [self createPureColorImage: UIColor.greenColor alpha: 1];
    _img1 = [self createPureColorImage: UIColor.redColor alpha: 0.5];
    
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self createBuffers];
    [self setupVAOs];
    [self loadTextures];
    
//    [self enableBlending];
    
    [self render: self.view.bounds.size];
    [self present];
}

// 内存管理
- (void)dealloc {
    glDeleteFramebuffers(1, &_FBO);
    glDeleteVertexArrays(2, _VAOs);
    glDeleteProgram(_program);
    free(_VAOs);
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
        kEAGLDrawablePropertyRetainedBacking: @(false), // Todo??
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
    };
    _glLayer.frame = self.view.bounds;
    [self.view.layer addSublayer: _glLayer];
}

- (void)setupPrograms {
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"Blend" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"Blend" ofType: @"fsh"];
    
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    _program = [OpenGLESUtils linkProgram: vertex
                             fragmentShader: fragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(_program, "position");
    _texCoorLoc = glGetAttribLocation(_program, "texCoor");
    
    _textureUniformLoc = glGetUniformLocation(_program, "tex");
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

    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)setupVAOs {
    _VAOs = malloc(sizeof(GLuint) * 2);
    _VAOs[0] = [self createVAO: vertices0 vSize: sizeof(vertices0)];
    _VAOs[1] = [self createVAO: vertices1 vSize: sizeof(vertices1)];
}

- (GLuint)createVAO: (const GLfloat*)vertices vSize: (GLuint)vSize {
    // 1. 初始化 VAO （接下来所有操作顶点操作都将加入到 VAO 中）
    GLuint VAO;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    
    // 1.1 构造 & 激活 VBO
    GLuint VBO[2];
    glGenBuffers(2, VBO);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]);
    glBufferData(GL_ARRAY_BUFFER, vSize, vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_positionLoc);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(texCoor), texCoor, GL_STATIC_DRAW);
    glVertexAttribPointer(_texCoorLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_texCoorLoc);
    
    // 1.1.1 初始化 & 激活 索引 VBO
    GLuint indexVBO;
    glGenBuffers(1, &indexVBO);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    // 1.2 停用当前 VAO & VBO，注意顺序 （好习惯，单个的时候可以不写）
    glBindVertexArray(0);
    
    glBindBuffer(VBO[0], 0);
    glBindBuffer(VBO[1], 0);
    
    return VAO;
}

- (void)loadTextures {
    _textureId0 = [OpenGLESUtils loadImageTexture: _img0];
    _textureId1 = [OpenGLESUtils loadImageTexture: _img1];
}

- (void)render: (CGSize)clearSize {
    glUseProgram(_program);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    
    // Render image 0
    
    glDisable(GL_BLEND);
    
    glActiveTexture(GL_TEXTURE0 + 2);
    glBindTexture(GL_TEXTURE_2D, _textureId0);
    glUniform1i(_textureUniformLoc, 2);
    
    glBindVertexArray(_VAOs[0]); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLES, sizeof(indices), GL_UNSIGNED_SHORT, 0);
    
    // Render image 1
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glActiveTexture(GL_TEXTURE0 + 3);
    glBindTexture(GL_TEXTURE_2D, _textureId1);
    glUniform1i(_textureUniformLoc, 3);
    
    glBindVertexArray(_VAOs[1]); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLES, sizeof(indices), GL_UNSIGNED_SHORT, 0);
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

#pragma mark - Create pure color images

- (UIImage *)createPureColorImage: (UIColor *)color
                            alpha: (CGFloat)alpha {
    
    UIColor *colorWithAlpha = [color colorWithAlphaComponent: alpha];
    
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [colorWithAlpha CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}

@end
