////  CustomFilterChainViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/13.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "CustomFilterChainViewController.h"

#import "OpenGLESUtils.h"

static const GLfloat vertices[] = {
    -1, -1, 0, // 左下角
    1, -1, 0, // 右下角
    -1, 1, 0, // 左上角
    1, 1, 0 // 右上角
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

@interface CustomFilterChainViewController ()
@property (weak, nonatomic) IBOutlet UIView *displayView;
@end

@implementation CustomFilterChainViewController {
    
    UIImage *_image;
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    // 纹理 id
    GLuint _imageTexture, _tmpTexture;
    
    // 纹理缓冲 id
    GLuint _imageTextureBufferIndex, _tmpTextureBufferIndex;
    
    // FBOs / RBO / VAOs
    GLuint *_FBOs, _RBO, *_VAOs;
    
    // Programs
    GLuint *_glPrograms;
    
    // Attributes 的 location
    GLuint _positionLoc;
    GLuint _texCoorLoc;
    
    // Uniforms 的 location （包括 texture 和参数）
    GLuint _imageTextureUniformLoc, _tmpBufferTextureUniformLoc;
    GLuint _grayIntensityUniformLoc, _brightnessUniformLoc;
    
    // Uniforms 参数的值
    CGFloat _grayIntensity;
    CGFloat _brightness;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setBackgroundColor: UIColor.whiteColor];
    
    _image = [UIImage imageNamed: @"avatar.JPG"];
    
    _grayIntensity = 0;
    _brightness = 0;
    
    _imageTextureBufferIndex = 5;
    _tmpTextureBufferIndex = 8;
    
    _FBOs = malloc(sizeof(GLuint) * 2);
    _VAOs = malloc(sizeof(GLuint) * 2);
    _glPrograms = malloc(sizeof(GLuint) * 2);
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self setupTempTexture: _image.size];
    [self setupImageTexure: _image];
    [self createBuffers];
    [self setupVAOs];
    
    [self render];
}

// 内存管理
- (void)dealloc {
    
    glDeleteFramebuffers(2, _FBOs);
    glDeleteVertexArrays(2, _VAOs);
    glDeleteProgram(_glPrograms[0]);
    glDeleteProgram(_glPrograms[1]);

    free(_FBOs);
    free(_VAOs);
    free(_glPrograms);
}

#pragma mark - Response

- (IBAction)grayChanged:(UISlider *)sender {
    _grayIntensity = sender.value;
    [self render];
}

- (IBAction)brightnessChanged:(UISlider *)sender {
    _brightness = sender.value;
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
    _glLayer.frame = _displayView.bounds;
    [_displayView.layer addSublayer: _glLayer];

}

- (void)setupPrograms {
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"PassthroughTexture" ofType: @"vsh"];
    NSString *grayFragmentPath = [[NSBundle mainBundle] pathForResource: @"GaryFilter" ofType: @"fsh"];
    NSString *brightnessFragmentPath = [[NSBundle mainBundle] pathForResource: @"BrightnessFilter" ofType: @"fsh"];
    
    GLuint grayVertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint grayFragment = [OpenGLESUtils createShader: grayFragmentPath type: GL_FRAGMENT_SHADER];
    
    GLuint brightnessVertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint brightnessFragment = [OpenGLESUtils createShader: brightnessFragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    _glPrograms[0] = [OpenGLESUtils linkProgram: grayVertex fragmentShader: grayFragment];
    _glPrograms[1] = [OpenGLESUtils linkProgram: brightnessVertex fragmentShader: brightnessFragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(_glPrograms[0], "position");
    _texCoorLoc = glGetAttribLocation(_glPrograms[0], "texCoor");
    
    _imageTextureUniformLoc = glGetUniformLocation(_glPrograms[0], "imageTexture");
    _grayIntensityUniformLoc = glGetUniformLocation(_glPrograms[0], "intensity");
    
    _tmpBufferTextureUniformLoc = glGetUniformLocation(_glPrograms[1], "tmpBufferTexture");
    _brightnessUniformLoc = glGetUniformLocation(_glPrograms[1], "brightness");
}

- (void)setupTempTexture: (CGSize)size {
    glGenTextures(1, &_tmpTexture);
    glBindTexture(GL_TEXTURE_2D, _tmpTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
}

- (void)setupImageTexure: (UIImage *)image {
    _imageTexture = [OpenGLESUtils loadImageTexture: image];
}

- (void)createBuffers {
    // 创建 RBO Render Buffer Object
    glGenRenderbuffers(1, &_RBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: _glLayer];
    
    // Then, FBOs..
    
    // 创建 FBO Frame Buffer Object
    glGenFramebuffers(2, _FBOs);
    
    // 配置 FBO[0] - Temp FrameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[0]); // 使用 FBO[0]，下面的激活 & 绑定操作都会对应到这个 FrameBuffer
    glActiveTexture(GL_TEXTURE0 + _imageTextureBufferIndex); // 使用这个 texture
    glBindTexture(GL_TEXTURE_2D, _imageTexture); // 绑定这个 texture 到 framebuffer（ 重要，如果没有这个，将无法上传纹理到 uniform ）
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _tmpTexture, 0);
    
    // 配置 FBO[1] - Render FrameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[1]); // 使用 FBO[1]，下面的激活 & 绑定操作都会对应到这个 FrameBuffer
    glActiveTexture(GL_TEXTURE0 + _tmpTextureBufferIndex); // 使用这个 texture
    glBindTexture(GL_TEXTURE_2D, _tmpTexture); // 绑定这个 texture 到 framebuffer（ 重要，如果没有这个，将无法上传纹理到 uniform ）
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _RBO);
}

- (void)clearFBO: (CGSize)size {
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)setupVAOs {
    _VAOs[0] = [self createVAO];
    _VAOs[1] = [self createVAO];
}

- (GLuint)createVAO {
    // 1. 初始化 VAO （接下来所有操作顶点操作都将加入到 VAO 中）
    GLuint VAO;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    
    // 1.1 构造 & 激活 VBO
    GLuint VBO[2];
    glGenBuffers(2, VBO);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
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

- (void)render_gray: (CGSize)clearSize {
    glUseProgram(_glPrograms[0]);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[0]);
    [self clearFBO: clearSize];
    glUniform1i(_imageTextureUniformLoc, _imageTextureBufferIndex);
    glUniform1f(_grayIntensityUniformLoc, _grayIntensity);
    glBindVertexArray(_VAOs[0]); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLE_STRIP, 2 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)render_brightness: (CGSize)clearSize {
    glUseProgram(_glPrograms[1]);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[1]);
    [self clearFBO: clearSize];
    glUniform1i(_tmpBufferTextureUniformLoc, _tmpTextureBufferIndex);
    glUniform1f(_brightnessUniformLoc, _brightness);
    glBindVertexArray(_VAOs[1]); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLE_STRIP, 2 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

- (void)render {
    [self render_gray: _image.size];
    [self render_brightness: _displayView.bounds.size];
    [self present];
}

@end
