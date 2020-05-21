////  RenderCameraYUVBufferViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/19.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "RenderCameraYUVBufferViewController.h"

#import <AVFoundation/AVFoundation.h>
#import "OpenGLESUtils.h"

#import "YUV_To_RGB_Matrices_Vectors.h"

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

@interface RenderCameraYUVBufferViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation RenderCameraYUVBufferViewController {
    
    AVCaptureSession *_session;
    dispatch_queue_t _captureQueue;
    bool _useFullRangeYUV; // 是否使用 FullRangeYUV，true 则是，false 则使用 VideoRange
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    CGSize _layerSize;
    
    // 摄像机与物体的距离 （z 轴）
    float _cameraDistance;
    
    // OpenGL 和 Core Video 之间的纹理缓存
    CVOpenGLESTextureCacheRef _textureCache;
    
    // 纹理缓冲 id
    GLuint _lumaTextureBufferIndex; // 亮度 texture buffer
    GLuint _chromaTextureBufferIndex; // 色差 texture buffer
    
    // FBOs / RBO / VAOs
    GLuint _FBO, _RBO, _VAO;
    
    // Programs
    GLuint _glProgram;
    
    // Attributes 的 location
    GLuint _positionLoc;
    GLuint _texCoorLoc;
    
    // Uniforms 的 location （包括 texture 和 matrix）
    GLuint _lumaTextureUniformLoc; // 亮度 texture Uniform
    GLuint _chromaTextureUniformLoc; // 色度 texture Uniform
    GLuint _YUV_To_RGB_MatrixUniformLoc; // YUV 转 RGB 矩阵 Uniform （601 / 709 & VideoRange / FullRange）
    GLuint _YUV_TranlationUniformLoc; // YUV 转 RGB 偏移 Uniform （VideoRange / FullRange）
    
    GLuint _modelMatrixUniformLoc,
    _viewMatrixUniformLoc,
    _projectionMatrixUniformLoc;
    
    // Uniforms Matrix & Vector 参数的值
    GLKMatrix4 _modelMatrix, _viewMatrix, _projectionMatrix;
    
    const GLfloat *_YUV_To_RGB_Matrix, *_YUV_Tranlation;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _useFullRangeYUV = false;
    
    _lumaTextureBufferIndex = 5;
    _chromaTextureBufferIndex = 7;
    
    _cameraDistance = 1;
    
    _modelMatrix = GLKMatrix4Identity;
    _viewMatrix = GLKMatrix4MakeLookAt(0, 0, _cameraDistance, 0, 0, 0, 0, 1, 0);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90),
                                                  self.view.bounds.size.width / self.view.bounds.size.height,
                                                  0.1,
                                                  10);
    
    // 配置摄像头，采集 YUV 数据
    if (_useFullRangeYUV) {
        [self setupCamera: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    } else {
        [self setupCamera: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    }
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

#pragma mark - 采集的 Pixel Buffer 转换成 OpenGL ES 的 Texturex
- (CVOpenGLESTextureRef)acquireTextureFromBuffer: (CVPixelBufferRef)buffer isLuma: (bool)isLuma {
    
    GLint format = isLuma ? GL_LUMINANCE : GL_LUMINANCE_ALPHA; // 1 channel : 2 channel，无论 ES2 还是 ES3 都用这两个
    size_t planeIndex = isLuma ? 0 : 1; // 选择某一个平面
    GLenum textureIndex = isLuma ? _lumaTextureBufferIndex : _chromaTextureBufferIndex;
    
    // 将 PixelBuffer 转成 OpenGL ES 的 Texture，并且将句柄存在 cvTexture 中
    CVOpenGLESTextureRef cvTexture;
    CVReturn res = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _textureCache,
                                                                buffer,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                format,
                                                                (GLsizei)CVPixelBufferGetWidthOfPlane(buffer, planeIndex),
                                                                (GLsizei)CVPixelBufferGetHeightOfPlane(buffer, planeIndex),
                                                                format,
                                                                GL_UNSIGNED_BYTE, // UInt8_t
                                                                planeIndex,
                                                                &cvTexture);
    
    // 错误设置上面的 internalFormat / format / type 参数都会导致 res 为 6683 ！
    // 出现 -6683 请检查上述参数！
    
    // 若传入的 buffer 为 nil，则会出现 -6661 错误
    
    if (res != kCVReturnSuccess) {
        NSLog(@"Read texture faild from sample buffer, %d", res);
    }
    
    // 激活 Texture & 为 Texture 设定纹理参数
    glActiveTexture(GL_TEXTURE0 + textureIndex);
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(cvTexture)); // CVOpenGLESTextureGetName 可以获得 texture id
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    // 重置 Context 的 GL_TEXTURE_2D，防止意外错误
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return cvTexture;
}

#pragma mark - 更新 YUV 转 RGB 的 Tramsform Matrix 和 Translation Vector

- (void)updateMatrixAndVector:(CVImageBufferRef)imageBuffer
                  isFullRange:(bool)isFullRange {
    
    CFTypeRef matrixType = CVBufferGetAttachment(imageBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    bool use601;
    
    if (matrixType != NULL) {
        use601 = CFStringCompare(matrixType, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo;
    } else {
        use601 = true;
    }
    
    if (use601) {
        _YUV_To_RGB_Matrix = isFullRange ? kColorConversion601FullRange : kColorConversion601;
    } else {
        _YUV_To_RGB_Matrix = kColorConversion709;
    }
    
    _YUV_Tranlation = isFullRange ? kColorTranslationFullRange : kColorTranslationVideoRange;
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
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"RenderCameraYUVBuffer" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"RenderCameraYUVBuffer" ofType: @"fsh"];
    
    GLuint vertex = [OpenGLESUtils createShader: vertexPath type: GL_VERTEX_SHADER];
    GLuint fragment = [OpenGLESUtils createShader: fragmentPath type: GL_FRAGMENT_SHADER];
    
    // program
    _glProgram = [OpenGLESUtils linkProgram: vertex
                             fragmentShader: fragment];
    
    // attribute or uniform location
    _positionLoc = glGetAttribLocation(_glProgram, "position");
    _texCoorLoc = glGetAttribLocation(_glProgram, "texCoor");
    
    _lumaTextureUniformLoc = glGetUniformLocation(_glProgram, "lumaTexture");
    _chromaTextureUniformLoc = glGetUniformLocation(_glProgram, "chromaTexture");
    
    _YUV_To_RGB_MatrixUniformLoc = glGetUniformLocation(_glProgram, "YUV_To_RGB_Matrix");
    _YUV_TranlationUniformLoc = glGetUniformLocation(_glProgram, "YUV_Translation");
    
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

- (void)render: (CGSize)clearSize lumaTextureId: (GLuint)lumaTextureId chromaTextureId: (GLuint)chromaTextureId {
    glUseProgram(_glProgram);
    glBindFramebuffer(GL_FRAMEBUFFER, _FBO);
    [self clearFBO: clearSize];
    
    // -- 上传 Uniforms -- Begin
    
    // MVP
    glUniformMatrix4fv(_modelMatrixUniformLoc, 1, GL_FALSE, _modelMatrix.m);
    glUniformMatrix4fv(_viewMatrixUniformLoc, 1, GL_FALSE, _viewMatrix.m);
    glUniformMatrix4fv(_projectionMatrixUniformLoc, 1, GL_FALSE, _projectionMatrix.m);
    
    // 亮度 texture
    glActiveTexture(GL_TEXTURE0 + _lumaTextureBufferIndex);
    glBindTexture(GL_TEXTURE_2D, lumaTextureId);
    glUniform1i(_lumaTextureUniformLoc, _lumaTextureBufferIndex);
    
    // 色度 texture
    glActiveTexture(GL_TEXTURE0 + _chromaTextureBufferIndex);
    glBindTexture(GL_TEXTURE_2D, chromaTextureId);
    glUniform1i(_chromaTextureUniformLoc, _chromaTextureBufferIndex);
    
    // YUV 转 RGB 矩阵和向量
    glUniformMatrix3fv(_YUV_To_RGB_MatrixUniformLoc, 1, GL_FALSE, _YUV_To_RGB_Matrix);
    glUniform3f(_YUV_TranlationUniformLoc, _YUV_Tranlation[0], _YUV_Tranlation[1], _YUV_Tranlation[2]);
    
    // -- 上传 Uniforms -- Finished
    
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
    NSArray *arr = [output availableVideoCVPixelFormatTypes];
    for (NSNumber *num in arr) {
        OSType type = num.unsignedIntValue;
        if (type == kCVPixelFormatType_32BGRA ||
            type == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
            type == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            NSLog(@"Assume correctly");
        } else {
            NSLog(@"Assume wrong");
        }
            
    }
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
    
    [self updateMatrixAndVector: imageBuffer isFullRange: _useFullRangeYUV]; // 更新 matrix 和 vector

    CVOpenGLESTextureRef lumaTexture = [self acquireTextureFromBuffer: imageBuffer isLuma: true]; // PixelBuffer => OpenGL Texture
    
    CVOpenGLESTextureRef chromaTexture = [self acquireTextureFromBuffer: imageBuffer isLuma: false]; // PixelBuffer => OpenGL Texture
    
    [self render: _layerSize
   lumaTextureId: CVOpenGLESTextureGetName(lumaTexture)
 chromaTextureId: CVOpenGLESTextureGetName(chromaTexture)];
    
    [self present];
    
    CVOpenGLESTextureCacheFlush(_textureCache, 0); // 渲染完毕之后清空一下 texture cache
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    if (lumaTexture != NULL) { // 如果 texture 为 NULL，再 Release 就会出现 `EXC_BREAKPOINT` crash！
        CFRelease(lumaTexture); // 没有这个，就会不再采集！！！！
    }
    if (chromaTexture != NULL) { // 如果 texture 为 NULL，再 Release 就会出现 `EXC_BREAKPOINT` crash！
        CFRelease(chromaTexture); // 没有这个，就会不再采集！！！！
    }
}

@end
