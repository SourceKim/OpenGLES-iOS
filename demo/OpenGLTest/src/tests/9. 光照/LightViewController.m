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
    
    // 正面
    -1, 1, 1,// 0
    1, 1, 1, // 1
    -1, -1, 1, // 3
    
    1, 1, 1, // 1
    1, -1, 1, // 2
    -1, -1, 1, // 3
    
    // 右面
    1, 1, 1, // 1
    1, -1, 1, // 2
    1, -1, -1, // 6
    
    1, 1, 1, // 1
    1, 1, -1, // 5
    1, -1, -1, // 6
    
    // 背面
    -1, 1, -1, // 4
    1, 1, -1, // 5
    -1, -1, -1, // 7
    
    1, 1, -1, // 5
    1, -1, -1, // 6
    -1, -1, -1, // 7
    
    // 左面
    -1, -1, 1, // 3
    -1, 1, -1, // 4
    -1, -1, -1, // 7
    
    -1, 1, 1,// 0
    -1, -1, 1, // 3
    -1, 1, -1, // 4
    
    // 上面
    -1, 1, 1,// 0
    1, 1, 1, // 1
    -1, 1, -1, // 4
   
    1, 1, 1, // 1
    -1, 1, -1, // 4
    1, 1, -1, // 5
    
    // 下面
    1, -1, 1, // 2
    -1, -1, 1, // 3
    1, -1, -1, // 6
    
    -1, -1, 1, // 3
    1, -1, -1, // 6
    -1, -1, -1, // 7
};

static const GLfloat normals[] = {
    
    // 正面
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    
    // 右面
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    
    // 背面
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    
    // 左面
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    
    // 上面
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    
    // 下面
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
};

@interface LightViewController ()

@end

@implementation LightViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    CADisplayLink *_dis;
    
    int _objRotateAngle; // 物体的旋转角度
    float _lightScale; // 灯的放大倍数
    float _objScale; // 物体的放大倍数
    
    GLKVector3 _lightColor; // 光照颜色
    GLKVector3 _objColor; // 物体颜色
    float _lightAmbientStrength; // 光照强度
    float _specularStrength; // 镜面光强度
    GLKVector3 _lightPosition; // 光源的位置
    GLKVector3 _objPosition; // 物体的位置
    GLKVector3 _eyePostion; // 摄像机（眼睛）的位置
    
    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _lightVAO, _objVAO, _depthRBO;
    
    // Programs
    GLuint _lightProgram, _objProgram;
    
    // Attributes 的 location
    GLuint _positionLoc;
    GLuint _normalLoc; // 法线 attribute 的位置
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _vertexColorUniformLoc;
    GLuint _modelMatrixUniformLoc,
    _viewMatrixUniformLoc,
    _projectionMatrixUniformLoc;
    
    GLuint _originColorUniformLoc; // 物体颜色
    GLuint _lightColorUniformLoc; // 光照颜色
    GLuint _needLightUniformLoc; // 是否需要光照
    GLuint _ambientStrengthUniformLoc; // 环境光强度 （通常很小）
    GLuint _lightPosUniformLoc; // 光源的位置
    GLuint _eyePosUniformLoc; // 摄像机（眼睛）的位置
    GLuint _specularStrengthUniformLoc; // 镜面光强度 （通常中等亮度）
    
    // Uniforms Matrix 参数的值
    
    GLKMatrix4 _lightModelMatrix, _objModelMatrix, _viewMatrix, _projectionMatrix;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _objScale = 2;
    _lightScale = 0.1;
    
    _lightColor = GLKVector3Make(1, 1, 1);
    _objColor = GLKVector3Make(0, 0.7, 0);
    _lightPosition = GLKVector3Make(2, 2, 3);
    _objPosition = GLKVector3Make(0, 0, 0);
    
    _eyePostion = GLKVector3Make(0, 0, 10);
    
    _objRotateAngle = 0;
    
    _lightAmbientStrength = 0.1;
    _specularStrength = 0.5;
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self createBuffers];
    [self setupVAOs];
    
    [self setupLightCube];
    [self rotateCube];
    
    _viewMatrix = GLKMatrix4MakeLookAt(_eyePostion.x, _eyePostion.y, _eyePostion.z, 0, 0, 0, 0, 1, 0);
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90),
                                                  self.view.bounds.size.width / self.view.bounds.size.height,
                                                  0.1,
                                                  100);
    
    _dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
    
//    [self render];
    
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

#pragma mark - Set up light Cube (By Model matrix)

- (void)setupLightCube {
    
    GLKMatrix4 lightTranslation = GLKMatrix4MakeTranslation(_lightPosition.x,
                                                            _lightPosition.y,
                                                            _lightPosition.z);
    GLKMatrix4 lightScale = GLKMatrix4MakeScale(_lightScale, _lightScale, _lightScale);
    
    _lightModelMatrix = GLKMatrix4Multiply(lightTranslation, lightScale);
    
}

#pragma mark - Rotate the Cube (By Model matrix)

- (void)rotateCube {
    
    GLKMatrix4 objTranslation = GLKMatrix4MakeTranslation(_objPosition.x, _objPosition.y, _objPosition.z);
    GLKMatrix4 objRotation = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(_objRotateAngle), 1, 1, 1);
    GLKMatrix4 objScale = GLKMatrix4MakeScale(_objScale, _objScale, _objScale);
    
    // 从后面读起：先 scale -> 再 rotate -> 最后 translate
    _objModelMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(objTranslation, objRotation), objScale);
    
    _objRotateAngle += 1;
    
    if (_objRotateAngle > 360) {
        _objRotateAngle = 0;
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
    _normalLoc = glGetAttribLocation(program, "normal");
    
    _modelMatrixUniformLoc = glGetUniformLocation(program, "modelMatrix");
    _viewMatrixUniformLoc = glGetUniformLocation(program, "viewMatrix");
    _projectionMatrixUniformLoc = glGetUniformLocation(program, "projectionMatrix");
    
    _originColorUniformLoc = glGetUniformLocation(program, "originColor");
    _needLightUniformLoc = glGetUniformLocation(program, "needLight");
    _lightColorUniformLoc = glGetUniformLocation(program, "lightColor");
    _ambientStrengthUniformLoc = glGetUniformLocation(program, "ambientStrength");
    _specularStrengthUniformLoc = glGetUniformLocation(program, "specularStrength");
    _lightPosUniformLoc = glGetUniformLocation(program, "lightPos");
    _eyePosUniformLoc = glGetUniformLocation(program, "eyePos");
    
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

- (void)render: (CGSize)clearSize {
    
    // 0. Bind the FBO & Clear the FBO
    
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    
    // 1. Render light
    
    glUseProgram(_lightProgram);
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _lightModelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    
    glUniform3f(_originColorUniformLoc, _lightColor.r, _lightColor.g, _lightColor.b); // 物体颜色
    glUniform1i(_needLightUniformLoc, 0); // 是否需要光照
    glUniform3f(_lightColorUniformLoc, _lightColor.r, _lightColor.g, _lightColor.b); // 光照颜色
    glUniform1f(_ambientStrengthUniformLoc, _lightAmbientStrength); // 环境光强度
    glUniform1f(_specularStrengthUniformLoc, _specularStrength); // 镜面光强度
    glUniform3f(_lightPosUniformLoc, _lightPosition.x, _lightPosition.y, _lightPosition.z); // 光源的位置
    glUniform3f(_eyePosUniformLoc, _eyePostion.x, _eyePostion.y, _eyePostion.z); // 眼睛（摄像机）的位置
    
    glBindVertexArray(_lightVAO); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
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
