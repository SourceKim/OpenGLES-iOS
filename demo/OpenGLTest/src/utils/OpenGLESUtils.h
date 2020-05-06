//
//  OpenGLESUtils.h
//  OpenGLTest
//
//  Created by 苏金劲 on 2020/5/7.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OpenGLES/ES3/gl.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenGLESUtils : NSObject

+ (GLuint)createShader: (NSString *)path type: (GLenum)type;

@end

NS_ASSUME_NONNULL_END
