////  PaintBoardTouchManager.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/28.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "PaintBoardTouchManager.h"

#define MiddlePoint(p1, p2) __MiddlePoint(p1, p2)

static inline CGPoint __MiddlePoint(CGPoint point1, CGPoint point2) {
    return CGPointMake((point1.x + point2.x) / 2, (point1.y + point2.y) / 2);
}

@interface PaintBoardTouchManager()

@property (nonatomic, weak) UIView * attachingView;

@end

@implementation PaintBoardTouchManager {
    CGPoint _from;
}

- (instancetype)initWithView: (UIView *)view
{
    self = [super init];
    if (self) {
        _attachingView = view;
    }
    return self;
}

- (void)onTouchBegan: (NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (![self checkDelegate]) return;
    
    CGFloat scale = [self.delegate screenScale];
    CGAffineTransform trans = CGAffineTransformMakeScale(scale, scale);
    
    CGPoint point = [[touches anyObject] locationInView: _attachingView];
    point = CGPointApplyAffineTransform(point, trans);
    
    [self.delegate onPointsOut: [self verticesFromPoints: @[@(point)]
                                                   scale: scale]];
    
    _from = point;
}

- (void)onTouchMovedOrEnded: (NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (![self checkDelegate]) return;
    
    CGFloat scale = [self.delegate screenScale];
    CGAffineTransform trans = CGAffineTransformMakeScale(scale, scale);
    
    UITouch *currentTouch = [touches anyObject];
    CGPoint previousPoint = [currentTouch previousLocationInView: _attachingView];
    CGPoint currentPoint = [currentTouch locationInView: _attachingView];
    
    previousPoint = CGPointApplyAffineTransform(previousPoint, trans);
    currentPoint = CGPointApplyAffineTransform(currentPoint, trans);
    
    CGPoint from = _from;
    CGPoint to = MiddlePoint(previousPoint, currentPoint);
    
    if (CGPointEqualToPoint(_from, currentPoint)) return;
    
    CGFloat pointSize = [self.delegate currentPointSize];
    
    NSMutableArray *points = [self getPoints: from
                                     toPoint: to
                               withPointSize: pointSize];
    
    [self.delegate onPointsOut: [self verticesFromPoints: points.copy
                                                   scale: scale]];
    
    _from = to;
}

- (NSArray<NSValue *> *)verticesFromPoints: (NSArray<NSValue *> *)points
                                     scale: (CGFloat)scale {
    
    NSMutableArray *mVertices = [NSMutableArray array];
    CGRect viewFrame = CGRectApplyAffineTransform(_attachingView.frame, CGAffineTransformMakeScale(scale, scale));
    for (NSValue *pv in points) {
        CGPoint p = pv.CGPointValue;
        
        CGPoint vertice = CGPointMake(p.x / CGRectGetWidth(viewFrame) * 2 - 1,
                                      (p.y / CGRectGetHeight(viewFrame) * 2 - 1) * -1);
        [mVertices addObject: [NSValue valueWithCGPoint: vertice]];
    }
    return mVertices.copy;
}

- (bool)checkDelegate {
    return (self.delegate &&
            [self.delegate respondsToSelector: @selector(onPointsOut:)] &&
            [self.delegate respondsToSelector: @selector(currentPointSize)]);
}

- (NSMutableArray<NSValue *> *)getPoints: (CGPoint)from
                                 toPoint: (CGPoint)to
                           withPointSize: (CGFloat)pointSize {
    
    CGFloat count = MAX(
                        ceilf(
                              sqrtf(
                                    powf(to.x - from.x, 2) +
                                    powf(to.y - from.y, 2)
                                    )
                              / pointSize),
                        1
                        );
    
    count += 10; // 经验值，这样可以让点稠密
    
    NSMutableArray *mPoints = [NSMutableArray array];
    
    for (int i = 0; i < count; i++) {
        
        CGFloat percent = (CGFloat)i / (CGFloat)count;
        [mPoints addObject: @(
         CGPointMake(from.x + (to.x - from.x) * percent,
                     from.y + (to.y - from.y) * percent)
         )];
    }
    
    return mPoints;
}

@end
