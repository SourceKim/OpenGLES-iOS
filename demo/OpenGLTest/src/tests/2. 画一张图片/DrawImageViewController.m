//
//  DrawImageViewController.m
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/8.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "DrawImageViewController.h"

#import "OpenGLESUtils.h"

@interface DrawImageViewController ()

@end

@implementation DrawImageViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    GLuint _FBO, _RBO;
    
    GLuint _glProgram;
    
    GLuint _positionLoc;
    GLuint _texCoorLoc;
    GLuint _texUniformLoc;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [self.view setBackgroundColor: [UIColor whiteColor]];
    
    [self setupContext];
    [self setupLayer];
    [self createBuffers];
    [self setupProgram];
    [self setupDrawable];
    [self setupImageTexure: [UIImage imageNamed: @"avatar.JPG"]];
    [self renderVertex_VBO_Index];
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
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"image" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"image" ofType: @"fsh"];
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
    
    _positionLoc = glGetAttribLocation(_glProgram, "position");
    _texCoorLoc = glGetAttribLocation(_glProgram, "texCoor");
    _texUniformLoc = glGetUniformLocation(_glProgram, "tex");
}

- (void)setupDrawable {
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
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

- (void)renderVertex_VBO_Index {
    
    // 1. 初始化 & 激活 VBO
    GLuint VBO[2];
    glGenBuffers(2, VBO);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]); // 使用这个缓冲对象（缓冲区有两个对象，需要告诉 OGL 下面的代码要使用哪一个
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_positionLoc);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(texCoor), texCoor, GL_STATIC_DRAW);
    glVertexAttribPointer(_texCoorLoc, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_texCoorLoc);
    
    // 1.1 初始化 & 激活 索引 VBO
    GLuint indexVBO;
    glGenBuffers(1, &indexVBO);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // 3. 渲染
    // 1 * 3 代表： 1 个面，每个面由 3 个顶点组成
    glDrawElements(GL_TRIANGLE_STRIP, 2 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)present {
    
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

- (void)setupImageTexure: (UIImage *)image {
    
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
