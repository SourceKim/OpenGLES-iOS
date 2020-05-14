//
//  OpenGLESUtils.h
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/7.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

typedef NS_ENUM(NSUInteger, OpenGLFillMode) {
    OpenGLFillMode_AspectRatioFit, // 保持比例，使图片缩放至完整居中显示 （`AspectFit`），多余部分留白
    OpenGLFillMode_AspectRatioFill, // 保持比例，使图片缩放至居中填充满 （`AspectFill`），超出部分裁剪
    OpenGLFillMode_ScaleToFill, // 不保持比例，使图片缩放至完全填满（`ScaleToFill`），此方法会变形
};

NS_ASSUME_NONNULL_BEGIN

@interface OpenGLESUtils : NSObject

+ (GLuint)createShader: (NSString *)path type: (GLenum)type;

+ (GLuint)linkProgram: (GLuint)vertexShader fragmentShader: (GLuint)fragmentShader;

/// 生成顶点
/// @param fillMode 模式
/// @param displayRatio 展示的纹理占 Viewport 的百分比
/// @param imageSize 纹理图片的 size
/// @param viewPortSize 显示区域 Viewport 的 size
+ (GLfloat *)generateVertices: (OpenGLFillMode)fillMode
             withDisplayRatio: (GLfloat)displayRatio
                withImageSize: (CGSize)imageSize
             withViewPortSize: (CGSize)viewPortSize;

+ (GLuint)loadImageTexture: (UIImage *)image;

+ (void)printMatrix4: (GLKMatrix4)matrix4;

@end

NS_ASSUME_NONNULL_END
