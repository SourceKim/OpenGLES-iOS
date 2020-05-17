////  TriangleViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/6.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "TriangleViewController.h"

#import "OpenGLESUtils.h"

@interface TriangleViewController ()
@end

@implementation TriangleViewController {
    
    EAGLContext * _ctx;
    
    CAEAGLLayer * _glLayer;
    
    GLuint _FBO, _RBO;
    
    GLuint _glProgram;
    
    GLuint _positionLoc;
    GLuint _colorLoc;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self.view setBackgroundColor: [UIColor whiteColor]];
    
    [self setupContext];
    [self setupLayer];
    [self createBuffers];
    [self setupProgram];
    [self setupDrawable];
    [self renderVertex_VAO_Index];
    [self present];
}

- (void)setupContext {
    
    _ctx = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext: _ctx];
    
    NSLog(@"CTX0： %@ - %@", [NSThread currentThread], [EAGLContext currentContext]);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"CTX1：%@ - %@", [NSThread currentThread], [EAGLContext currentContext]);
    });
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
    NSString *vertexPath = [[NSBundle mainBundle] pathForResource: @"passthrough" ofType: @"vsh"];
    NSString *fragmentPath = [[NSBundle mainBundle] pathForResource: @"passthrough" ofType: @"fsh"];
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
    _colorLoc = glGetAttribLocation(_glProgram, "vColor");
}

- (void)setupDrawable {
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
}

static const GLfloat vertices[] = {
    0, 0.5, 0,
    -0.5, -0.5, 0,
    0.5, -0.5, 0
};

static const GLfloat color_data[] = {
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
};

static const GLushort indices[] = {
  0, 1, 2,
};

/// 离屏渲染相关：

- (void)renderVertex_Directly {
    
    // 1. 上传顶点
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(_positionLoc);
    
    glVertexAttribPointer(_colorLoc, 3, GL_FLOAT, GL_FALSE, 0, color_data);
    glEnableVertexAttribArray(_colorLoc);
    
    // 2. 渲染
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

- (void)renderVertex_VBO {
    
    // 1. 初始化 & 激活 VBO
    GLuint VBO[2];
    glGenBuffers(2, VBO);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]); // 使用这个缓冲对象（缓冲区有两个对象，需要告诉 OGL 下面的代码要使用哪一个
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_positionLoc);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(color_data), color_data, GL_STATIC_DRAW);
    glVertexAttribPointer(_colorLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_colorLoc);

    // 3. 渲染
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

- (void)renderVertex_VAO {
    
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
    glBufferData(GL_ARRAY_BUFFER, sizeof(color_data), color_data, GL_STATIC_DRAW);
    glVertexAttribPointer(_colorLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_colorLoc);
    
    // 1.2 停用当前 VAO & VBO，注意顺序 （好习惯，单个的时候可以不写）
    glBindVertexArray(0);
    
    glBindBuffer(VBO[0], 0);
    glBindBuffer(VBO[1], 0);
    
    // 2. 渲染
    
    // 2.1 使用 VAO，因为在 1.2 中停用了
    glBindVertexArray(VAO);
    
    // 2.2 渲染
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

- (void)renderVertex_Directly_Index {
    
    // 1. 上传顶点
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(_positionLoc);
    
    glVertexAttribPointer(_colorLoc, 3, GL_FLOAT, GL_FALSE, 0, color_data);
    glEnableVertexAttribArray(_colorLoc);
    
    // 2. 渲染
    // 1 * 3 代表： 1 个面，每个面由 3 个顶点组成
    glDrawElements(GL_TRIANGLE_STRIP, 1 * 3, GL_UNSIGNED_SHORT, indices);
}

- (void)renderVertex_VBO_Index {
    
    // 1. 初始化 & 激活 VBO
    GLuint VBO[2];
    glGenBuffers(2, VBO);
    
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[0]); // 使用这个缓冲对象（缓冲区有两个对象，需要告诉 OGL 下面的代码要使用哪一个
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(_positionLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_positionLoc);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(color_data), color_data, GL_STATIC_DRAW);
    glVertexAttribPointer(_colorLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_colorLoc);
    
    // 1.1 初始化 & 激活 索引 VBO
    GLuint indexVBO;
    glGenBuffers(1, &indexVBO);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // 3. 渲染
    // 1 * 3 代表： 1 个面，每个面由 3 个顶点组成
    glDrawElements(GL_TRIANGLE_STRIP, 1 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)renderVertex_VAO_Index {
    
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
    glBufferData(GL_ARRAY_BUFFER, sizeof(color_data), color_data, GL_STATIC_DRAW);
    glVertexAttribPointer(_colorLoc, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glEnableVertexAttribArray(_colorLoc);
    
    // 1.1.1 初始化 & 激活 索引 VBO
    GLuint indexVBO;
    glGenBuffers(1, &indexVBO);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexVBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    // 1.2 停用当前 VAO & VBO，注意顺序 （好习惯，单个的时候可以不写）
    glBindVertexArray(0);
    
    glBindBuffer(VBO[0], 0);
    glBindBuffer(VBO[1], 0);
    
    // 2. 渲染
    
    // 2.1 使用 VAO，因为在 1.2 中停用了
    glBindVertexArray(VAO);
    
    // 2.2 渲染
    // 1 * 3 代表： 1 个面，每个面由 3 个顶点组成
    glDrawElements(GL_TRIANGLE_STRIP, 1 * 3, GL_UNSIGNED_SHORT, 0);
}

- (void)present {
    
    [_ctx presentRenderbuffer: GL_RENDERBUFFER];
}


@end
