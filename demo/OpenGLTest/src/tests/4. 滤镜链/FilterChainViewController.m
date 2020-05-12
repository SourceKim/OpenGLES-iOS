////  FilterChainViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/12.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "FilterChainViewController.h"

#import "OpenGLESUtils.h"
#import <OpenGLES/ES2/glext.h>

@interface FilterChainViewController ()

@end

@implementation FilterChainViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    GLuint _imageTexture, _tmpTexture;
    
    GLuint *_FBOs, _RBO, *_VAOs;
    
    GLuint *_glPrograms;
    
    GLuint _positionLoc;
    GLuint _texCoorLoc;
    GLuint _texUniformLoc;
    GLuint _brightnessUniformLoc;
    
    CGFloat _brightness;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    glInsertEventMarkerEXT(0, "com.apple.GPUTools.event.debug-frame");
    
    UIImage *image = [UIImage imageNamed: @"avatar.JPG"];
    CGSize viewPortSize = self.view.bounds.size;
    
    _brightness = 0.5;
    
    [self setupContext];
    [self setupLayer];
    [self createTmpBuffer: image.size];
    [self createBuffers];
    [self setupProgram];
    [self setupDrawable: viewPortSize];
    [self setupImageTexure: image];
    [self setupVAOs];
    [self render_gray];
    [self render_brightness];
    [self present];
}

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

- (void)createTmpBuffer: (CGSize)size {
    glEnable(GL_TEXTURE_2D);
    glGenTextures(1, &_tmpTexture);
    glBindTexture(GL_TEXTURE_2D, _tmpTexture);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0); // TODO: NULL?
    
    glBindTexture(GL_TEXTURE_2D, 0); // unbind
}

- (void)createBuffers {
    
    // 创建 Render Buffer Object
    glGenRenderbuffers(1, &_RBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: _glLayer];
    
    _FBOs = malloc(sizeof(GLuint) * 2);
    
    // 创建 Frame Buffer Object
    glGenFramebuffers(2, _FBOs);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[0]);
//    glBindTexture(GL_TEXTURE_2D, _tmpTexture);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _tmpTexture, 0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[1]);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _RBO);
}

- (void)setupProgram {
    
    _glPrograms = malloc(sizeof(GLuint) * 2);
    
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
    _texUniformLoc = glGetUniformLocation(_glPrograms[0], "tex");
    _brightnessUniformLoc = glGetUniformLocation(_glPrograms[1], "brightness");
    
    glUseProgram(_glPrograms[0]);
}

- (void)setupDrawable: (CGSize)viewPortSize {
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, viewPortSize.width, viewPortSize.height);
}

- (void)setupVAOs {
    
    _VAOs = malloc(sizeof(GLuint) * 2);
    
    glUseProgram(_glPrograms[0]);
    _VAOs[0] = [self createVAO];
    
    glUseProgram(_glPrograms[1]);
    _VAOs[1] = [self createVAO];
    
}

static const GLfloat vertices[] = {
    -0.5, -0.5, 0, // 左下角
    0.5, -0.5, 0, // 右下角
    -0.5, 0.5, 0, // 左上角
    0.5, 0.5, 0 // 右上角
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

- (void)render_gray {
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[0]);
    glBindVertexArray(_VAOs[0]);
    glDrawElements(GL_TRIANGLE_STRIP, 2 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)render_brightness {
    glBindFramebuffer(GL_FRAMEBUFFER, _FBOs[1]);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    glUseProgram(_glPrograms[1]);
    glUniform1f(_brightnessUniformLoc, _brightness);
    glBindVertexArray(_VAOs[1]);
    glDrawElements(GL_TRIANGLE_STRIP, 2 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)present {
    
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

- (void)setupImageTexure: (UIImage *)image {
    
    glUseProgram(_glPrograms[0]);
    
    GLuint textureId = [self loadImageTexture: image];
    
    glActiveTexture(GL_TEXTURE3); // 使用（激活） 3 号纹理 buffer， 也可以是 GL_TEXTURE0 + 3
    glBindTexture(GL_TEXTURE_2D, textureId); // 将上面激活的纹理，与 加载纹理后返回的 id 绑定
    glUniform1i(_texUniformLoc, 3); // 将 激活的 3 号纹理，指定到 uniform 中，给着色器使用
}

- (GLuint)loadImageTexture: (UIImage *)image {
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
    
    glEnable(GL_TEXTURE_2D);
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

@end
