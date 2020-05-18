////  RenderCameraBufferViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/18.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "RenderCameraBufferViewController.h"

#import <AVFoundation/AVFoundation.h>
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

@interface RenderCameraBufferViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation RenderCameraBufferViewController {
    
    AVCaptureSession *_session;
    dispatch_queue_t _captureQueue;
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    CGSize _layerSize;
    
    // 摄像机与物体的距离 （z 轴）
    float _cameraDistance;
    
    // OpenGL 和 Core Video 之间的纹理缓存
    CVOpenGLESTextureCacheRef _textureCache;
    
    // 纹理缓冲 id
    GLuint _textureBufferIndex;
    
    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _VAO;
    
    // Programs
    GLuint _glProgram;
    
    // Attributes 的 location
    GLuint _positionLoc;
    GLuint _texCoorLoc;
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _textureUniformLoc;
    GLuint _modelMatrixUniformLoc,
    _viewMatrixUniformLoc,
    _projectionMatrixUniformLoc;
    
    // Uniforms Matrix 参数的值
    GLKMatrix4 _modelMatrix, _viewMatrix, _projectionMatrix;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _textureBufferIndex = 5;
    
    _cameraDistance = 1;
    
    _modelMatrix = GLKMatrix4Identity;
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, _cameraDistance, 0, 0, 0, 0, 1, 0);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90),
                                                  self.view.bounds.size.width / self.view.bounds.size.height,
                                                  0.1,
                                                  10);
    
    // 配置摄像头，采集 BGRA 数据
    [self setupCamera: kCVPixelFormatType_32BGRA];
}

// 在这儿 setup，能保证 glLayer 的 size 是正确的，否则更新它的 frame 可能会出错
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupContext];
    [self setupLayer];
    [self setupPrograms];
    [self setupCVOpenGLTextureCache];
    [self createBuffers];
    [self setupVAOs];
    
    [AVCaptureDevice requestAccessForMediaType: AVMediaTypeVideo
                             completionHandler:^(BOOL granted) {
        if (granted) {
            [self->_session startRunning];
        }
    }];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    
    [_session stopRunning];
}

// 内存管理
- (void)dealloc {
    
    CVOpenGLESTextureCacheFlush(_textureCache, 0);
    glDeleteFramebuffers(1, &_FBO);
    glDeleteVertexArrays(1, &_VAO);
    glDeleteProgram(_glProgram);
}

#pragma mark - 采集的 Pixel Buffer 转换成 OpenGL ES 的 Texture
- (CVOpenGLESTextureRef)acquireTextureFromBuffer: (CVPixelBufferRef)buffer {
    
    // 将 PixelBuffer 转成 OpenGL ES 的 Texture，并且将句柄存在 cvTexture 中
    CVOpenGLESTextureRef cvTexture;
    CVReturn res = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _textureCache,
                                                                buffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RGBA,
                                                                (GLsizei)CVPixelBufferGetWidth(buffer),
                                                                (GLsizei)CVPixelBufferGetHeight(buffer),
                                                                GL_RGBA,
                                                                GL_UNSIGNED_BYTE, // UInt8_t
                                                                0,
                                                                &cvTexture);
    
    // 错误设置上面的 internalFormat / format / type 参数都会导致 res 为 6683 ！
    // 出现 -6683 请检查上述参数！
    
    // 若传入的 buffer 为 nil，则会出现 -6661 错误
    
    if (res != kCVReturnSuccess) {
        NSLog(@"Read texture faild from sample buffer, %d", res);
    }
    
    // 激活 Texture & 为 Texture 设定纹理参数
    glActiveTexture(GL_TEXTURE0 + _textureBufferIndex);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(cvTexture)); // CVOpenGLESTextureGetName 可以获得 texture id
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    // 重置 Context 的 GL_TEXTURE_2D，防止意外错误
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return cvTexture;
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
    
    _layerSize = _glLayer.bounds.size;
}

- (void)setupPrograms {
    // shaders
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"RenderCameraBuffer" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"RenderCameraBuffer" ofType: @"fsh"];
    
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    _glProgram = [OpenGLESUtils linkProgram: vertex
                             fragmentShader: fragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(_glProgram, "position");
    _texCoorLoc = glGetAttribLocation(_glProgram, "texCoor");
    
    _textureUniformLoc = glGetUniformLocation(_glProgram, "imageTexture");
    
    _modelMatrixUniformLoc = glGetUniformLocation(_glProgram, "modelMatrix");
    _viewMatrixUniformLoc = glGetUniformLocation(_glProgram, "viewMatrix");
    _projectionMatrixUniformLoc = glGetUniformLocation(_glProgram, "projectionMatrix");
}

- (void)setupCVOpenGLTextureCache {
    
    CVReturn res = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _ctx, NULL, &_textureCache);
    
    if (res != kCVReturnSuccess) {
        NSLog(@"Create cache failed");
    }
}

- (void)createBuffers {
    // 创建 RBO Render Buffer Object
    glGenRenderbuffers(1, &_RBO);
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx renderbufferStorage: GL_RENDERBUFFER fromDrawable: _glLayer];
    
    // Then, FBOs..
    
    // 创建 FBO Frame Buffer Object
    glGenFramebuffers(1, &_FBO);
    
    // 配置 FBO - Render FrameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _RBO);
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

- (void)clearFBO: (CGSize)size {
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, size.width, size.height);
}

- (void)render: (CGSize)clearSize {
    glUseProgram(_glProgram);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    glUniform1i(_textureUniformLoc, _textureBufferIndex);
    glBindVertexArray(_VAO); // 使用 VAO 的好处，就是一句 bind 来使用对应 VAO 即可
    glDrawElements(GL_TRIANGLE_STRIP, 2 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)present {
    glBindRenderbuffer(GL_RENDERBUFFER, _RBO);
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}

#pragma mark - AVFoundation 设置 Camera

- (bool)setupCamera: (OSType)pixelFormatType {
    
    _session = [[AVCaptureSession alloc] init];
    _captureQueue = dispatch_queue_create(0, 0);
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeVideo];
    device = [AVCaptureDevice defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                mediaType: AVMediaTypeVideo
                                                 position: AVCaptureDevicePositionFront];
    
    if (device == nil) {
        return false;
    }
    
    NSError *err;
    AVCaptureInput *input = [[AVCaptureDeviceInput alloc] initWithDevice: device error: &err];
    
    if (input == nil || err != nil) {
        return false;
    }
    
    [_session beginConfiguration];
    _session.sessionPreset = AVCaptureSessionPreset640x480;
    
    if (![_session canAddInput: input]) {
        [_session commitConfiguration];
        return false;
    }
    [_session addInput: input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey: @(pixelFormatType) };
    [output setAlwaysDiscardsLateVideoFrames: true];
    [output setSampleBufferDelegate: self queue: _captureQueue];
    
    if (![_session canAddOutput: output]) {
        [_session commitConfiguration];
        return false;
    }
    [_session addOutput: output];
    
    AVCaptureConnection *connection = [output connectionWithMediaType: AVMediaTypeVideo];
    
    if (connection == nil) {
        [_session commitConfiguration];
        return false;
    }
    
    // 因为 OpenGL 的纹理 Y 轴和 UIKit 的是相反的，所以这里采集需要上下颠倒
    connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
//    [connection setVideoMirrored: true];
    
    [_session commitConfiguration];
    return true;
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    // 由于该回调在 子线程 回调，一个线程对应一个 Context，因此要把 Context 更新到当前线程
    if ([EAGLContext currentContext] == NULL) {
        [EAGLContext setCurrentContext: _ctx];
    }
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    CVOpenGLESTextureRef texture = [self acquireTextureFromBuffer: imageBuffer]; // PixelBuffer => OpenGL Texture
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(texture)); // 这里注意要绑定这个 texture 到上下文，否则
    
    [self render: _layerSize];
    [self present];
    
    CVOpenGLESTextureCacheFlush(_textureCache, 0); // 渲染完毕之后清空一下 texture cache
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    if (texture != NULL) { // 如果 texture 为 NULL，再 Release 就会出现 `EXC_BREAKPOINT` crash！
        CFRelease(texture); // 没有这个，就会不再采集！！！！
    }
    
    
}

@end
