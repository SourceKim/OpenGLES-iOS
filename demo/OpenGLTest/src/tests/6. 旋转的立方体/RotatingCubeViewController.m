//
//  RotatingCubeViewController.m
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/15.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "RotatingCubeViewController.h"

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

static const GLfloat vertexColor[] = {
    1, 0, 0, // 0
    1, 1, 0, // 1
    1, 1, 1, // 2
    1, 0, 1, // 3
    0, 1, 0, // 4
    0, 1, 1, // 5
    0, 0, 1, // 6
    0, 0, 0, // 7
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

@interface RotatingCubeViewController ()

@end

@implementation RotatingCubeViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    CADisplayLink *_dis;
    
    // 当前摄像机的角度
    int _cameraDegree;
    
    // 摄像机与物体的距离 （z 轴）
    float _cameraDistance;
    
    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _VAO, _depthRBO;
    
    // Programs
    GLuint _glProgram;
    
    // Attributes 的 location
    GLuint _positionLoc;
    GLuint _vertexColorLoc;
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _vertexColorUniformLoc;
    GLuint _modelMatrixUniformLoc,
    _viewMatrixUniformLoc,
    _projectionMatrixUniformLoc;
    
    // Uniforms Matrix 参数的值
    
    GLKMatrix4 _modelMatrix, _viewMatrix, _projectionMatrix;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _cameraDistance = -5;
    
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self createBuffers];
    [self setupVAOs];
    
    _modelMatrix = GLKMatrix4Identity;
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, _cameraDistance, 0, 0, 0, 0, 1, 0);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90),
                                                  self.view.bounds.size.width / self.view.bounds.size.height,
                                                  0.1,
                                                  100);
    
    _dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    
    [_dis invalidate];
}

// 内存管理
- (void)dealloc {
    glDeleteFramebuffers(1, &_FBO);
    glDeleteVertexArrays(1, &_VAO);
    glDeleteProgram(_glProgram);
}

#pragma mark - Rotate the Cube

- (void)rotateCube {
    double time = [[NSDate date] timeIntervalSince1970];
    float angle = sin(time / 2);
    _modelMatrix = GLKMatrix4MakeRotation(angle * M_PI * 2, 1, 1, 1);
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
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"RotatingCube" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"RotatingCube" ofType: @"fsh"];
    
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    _glProgram = [OpenGLESUtils linkProgram: vertex
                             fragmentShader: fragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(_glProgram, "position");
    _vertexColorLoc = glGetAttribLocation(_glProgram, "vertexColor");
    
    _modelMatrixUniformLoc = glGetUniformLocation(_glProgram, "modelMatrix");
    _viewMatrixUniformLoc = glGetUniformLocation(_glProgram, "viewMatrix");
    _projectionMatrixUniformLoc = glGetUniformLocation(_glProgram, "projectionMatrix");
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
    _VAO = [self createVAO];
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
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertexColor), vertexColor, GL_STATIC_DRAW);
    glVertexAttribPointer(_vertexColorLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_vertexColorLoc);
    
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

- (void)render: (CGSize)clearSize {
    glUseProgram(_glProgram);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    glBindVertexArray(_VAO); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
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
    [self rotateCube];
    [self render: _glLayer.bounds.size];
    [self present];
}

@end
