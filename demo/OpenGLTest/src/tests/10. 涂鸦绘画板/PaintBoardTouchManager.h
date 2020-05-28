////  PaintBoardTouchManager.h
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/28.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PaintBoardTouchManagerDelegate <NSObject>

- (void)onPointsOut: (NSArray<NSValue *> * _Nullable)points;

- (CGFloat)currentPointSize;

@end

NS_ASSUME_NONNULL_BEGIN

@interface PaintBoardTouchManager : NSObject

@property (nonatomic, weak) id<PaintBoardTouchManagerDelegate> delegate;

- (instancetype)initWithView: (UIView *)view;

- (void)onTouchBegan: (NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;

- (void)onTouchMovedOrEnded: (NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
