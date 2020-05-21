//
//  LightViewController.m
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/22.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "LightViewController.h"

#import "OpenGLESUtils.h"

static const GLfloat vertices[] = {
    -1, 1, 1,// 0
    1, 1, 1, // 1
    1, -1, 1, // 2
    -1, -1, 1, // 3
    -1, 1, -1, // 4
    1, 1, -1, // 5
    1, -1, -1, // 6
    -1, -1, -1 // 7
};

static const GLushort indices[] = {
    
    // 正面
    0, 1, 3,
    1, 2, 3,
    
    // 右面
    1, 2, 6,
    1, 5, 6,
    
    // 背面
    4, 5, 7,
    5, 6, 7,
    
    // 左面
    3, 4, 7,
    0, 3, 4,
    
    // 上面
    0, 1, 4,
    1, 4, 5,
    
    // 下面
    2, 3, 6,
    3, 6, 7,
    
};

@interface LightViewController ()

@end

@implementation LightViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    CADisplayLink *_dis;
    
    GLKVector3 _lightColor; // 光照颜色
    GLKVector3 _objColor; // 物体颜色
    float _lightAmbientStrenth; // 光照强度
    
    // 当前摄像机的角度
    int _cameraDegree;
    
    // 摄像机与物体的距离 （z 轴）
    float _cameraDistance;
    
    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _lightVAO, _objVAO, _depthRBO;
    
    // Programs
    GLuint _lightProgram, _objProgram;
    
    // Attributes 的 location
    GLuint _positionLoc;
    
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _vertexColorUniformLoc;
    GLuint _modelMatrixUniformLoc,
    _viewMatrixUniformLoc,
    _projectionMatrixUniformLoc;
    
    GLuint _originColorUniformLoc; // 物体颜色
    GLuint _lightColorUniformLoc; // 光照颜色
    GLuint _needLightUniformLoc; // 是否需要光照
    GLuint _ambientStrenthUniformLoc; // 环境光强度 （通常很小）
    
    // Uniforms Matrix 参数的值
    
    GLKMatrix4 _lightModelMatrix, _objModelMatrix, _viewMatrix, _projectionMatrix;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _lightColor = GLKVector3Make(1, 1, 1);
    _objColor = GLKVector3Make(0, 1, 0);
    
    _lightAmbientStrenth = 0.1;
    
    _cameraDistance = 10;
    
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self createBuffers];
    [self setupVAOs];
    
    GLKMatrix4 rotate = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(30), 0.5, 0.7, 0.5);
    
    GLKMatrix4 lightTranslation = GLKMatrix4MakeTranslation(6, 6, 0);
    GLKMatrix4 lightScale = GLKMatrix4MakeScale(0.5, 0.5, 0.5);
    
    GLKMatrix4 objTranslation = GLKMatrix4MakeTranslation(-1, -3, 3);
    
    _lightModelMatrix = GLKMatrix4Multiply(lightScale, GLKMatrix4Multiply(lightTranslation, rotate));
    
    _objModelMatrix = GLKMatrix4Multiply(objTranslation, rotate);;
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, _cameraDistance, 0, 0, 0, 0, 1, 0);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90),
                                                  self.view.bounds.size.width / self.view.bounds.size.height,
                                                  0.1,
                                                  100);
    
    [self render];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    
    [_dis invalidate];
}

// 内存管理
- (void)dealloc {
    glDeleteFramebuffers(1, &_FBO);
    glDeleteVertexArrays(1, &_lightVAO);
    glDeleteVertexArrays(1, &_objVAO);
    glDeleteProgram(_lightProgram);
    glDeleteProgram(_objProgram);
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
    _lightProgram = [self createProgram];
    _objProgram = [self createProgram];
}

- (GLuint)createProgram {
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"Light" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"Light" ofType: @"fsh"];
    
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    
    GLuint program = [OpenGLESUtils linkProgram: vertex
                                 fragmentShader: fragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(program, "position");
    
    _modelMatrixUniformLoc = glGetUniformLocation(program, "modelMatrix");
    _viewMatrixUniformLoc = glGetUniformLocation(program, "viewMatrix");
    _projectionMatrixUniformLoc = glGetUniformLocation(program, "projectionMatrix");
    
    _originColorUniformLoc = glGetUniformLocation(program, "originColor");
    _needLightUniformLoc = glGetUniformLocation(program, "needLight");
    _lightColorUniformLoc = glGetUniformLocation(program, "lightColor");
    _ambientStrenthUniformLoc = glGetUniformLocation(program, "ambientStrength");
    
    return program;
}

- (void)createBuffers {
    
    // 创建 RBO Render Buffer Object
    glGenRenderbuffers(1, &_RBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: _glLayer];
    
    // 申请 深度 buffer
    glGenRenderbuffers(1, &_depthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRBO);
    // 分配 深度 buffer 的存储区
    glRenderbufferStorage(GL_RENDERBUFFER,
                          GL_DEPTH_COMPONENT16,
                          _glLayer.bounds.size.width,
                          _glLayer.bounds.size.height);
    
    // Then, FBOs..
    
    // 创建 FBO Frame Buffer Object
    glGenFramebuffers(1, &_FBO);
    
    // 配置 FBO - Render FrameBuffer：
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO); // 使用 FBO，下面的激活 & 绑定操作都会对应到这个 FrameBuffer
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRBO); // 附着 深度 RBO
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _RBO); // 附着 渲染的颜色 RBO
}

- (void)clearFBO: (CGSize)size {

    glClearColor(0, 0, 0, 1);
    glClearDepthf(1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)setupVAOs {
    _lightVAO = [self createVAO];
    _objVAO = [self createVAO];
}

- (GLuint)createVAO {
    // 1. 初始化 VAO （接下来所有操作顶点操作都将加入到 VAO 中）
    GLuint VAO;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    
    // 1.1 构造 & 激活 VBO
    GLuint VBO[1];
    glGenBuffers(1, VBO);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_positionLoc);
    
    // 1.1.1 初始化 & 激活 索引 VBO
    GLuint indexVBO;
    glGenBuffers(1, &indexVBO);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    // 1.2 停用当前 VAO & VBO，注意顺序 （好习惯，单个的时候可以不写）
    glBindVertexArray(0);
    
    glBindBuffer(VBO[0], 0);
    
    return VAO;
}

- (void)render: (CGSize)clearSize {
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    
    glUseProgram(_lightProgram);
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _lightModelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    
    glUniform3f(_originColorUniformLoc, _lightColor.r, _lightColor.g, _lightColor.b); // 物体颜色
    glUniform1i(_needLightUniformLoc, 0); // 是否需要光照
    glUniform3f(_lightColorUniformLoc, _lightColor.r, _lightColor.g, _lightColor.b); // 光照颜色
    glUniform1f(_ambientStrenthUniformLoc, _lightAmbientStrenth); // 光照强度
    
    glBindVertexArray(_lightVAO); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLES, sizeof(indices), GL_UNSIGNED_SHORT, 0);
    
    glUseProgram(_objProgram);
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _objModelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    
    glUniform3f(_originColorUniformLoc, _objColor.r, _objColor.g, _objColor.b); // 物体颜色
    glUniform1i(_needLightUniformLoc, 1); // 是否需要光照
    glUniform3f(_lightColorUniformLoc, _lightColor.r, _lightColor.g, _lightColor.b); // 光照颜色
    glUniform1f(_ambientStrenthUniformLoc, _lightAmbientStrenth); // 光照强度
    
    glBindVertexArray(_objVAO); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLES, sizeof(indices), GL_UNSIGNED_SHORT, 0);
    
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

- (void)render {
//    int depth;
//    glGetIntegerv(GL_DEPTH_BITS, &depth);
//    NSLog(@"%i bits depth", depth);
//    [self rotateCube];
    [self render: _glLayer.bounds.size];
    [self present];
}
@end
