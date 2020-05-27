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
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
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
    glClearDepthf(1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)setupVBO {
    glGenBuffers(1, &_VBO);
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
    glBufferData(GL_ARRAY_BUFFER, sizeof(normals), normals, GL_STATIC_DRAW);
    glVertexAttribPointer(_normalLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_normalLoc);
    
    // 1.2 停用当前 VAO & VBO，注意顺序 （好习惯，单个的时候可以不写）
    glBindVertexArray(0);
    
    glBindBuffer(VBO[0], 0);
    
    return VAO;
}

- (void)render: (CGSize)clearSize
        points: (NSArray<NSValue *> *)points {
    
    // 0. Bind the FBO & Clear the FBO
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    
    // 1. Render light
    
    glUseProgram(_program);
    
    glUniform3f(_colorUniformLoc, 1, 0, 0); // 物体颜色
    
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(Vertex) * self.vertexCount;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), NULL + offsetof(Vertex, positionCoord));
    
    glDrawArrays(GL_TRIANGLES, 0, sizeof(vertices) / 3);
    
    // 2. Render Object
    
    glUseProgram(_objProgram);
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _objModelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    
    glUniform3f(_originColorUniformLoc, _objColor.r, _objColor.g, _objColor.b); // 物体颜色
    glUniform1i(_needLightUniformLoc, 1); // 是否需要光照
    glUniform3f(_lightColorUniformLoc, _lightColor.r, _lightColor.g, _lightColor.b); // 光照颜色
    glUniform1f(_ambientStrengthUniformLoc, _lightAmbientStrength); // 环境光强度
    glUniform1f(_specularStrengthUniformLoc, _specularStrength); // 镜面光强度
    glUniform3f(_lightPosUniformLoc, _lightPosition.x, _lightPosition.y, _lightPosition.z); // 光源的位置
    glUniform3f(_eyePosUniformLoc, _eyePostion.x, _eyePostion.y, _eyePostion.z); // 眼睛（摄像机）的位置
    
    glBindVertexArray(_objVAO); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawArrays(GL_TRIANGLES, 0, sizeof(vertices) / 3);
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

- (void)render {
//    int depth;
//    glGetIntegerv(GL_DEPTH_BITS, &depth);
//    NSLog(@"%i bits depth", depth);
    [self rotateCube];
    [self render: _glLayer.bounds.size];
    [self present];
}

@end
