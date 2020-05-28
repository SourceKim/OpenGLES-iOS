////  PaintBoardTouchManager.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/28.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "PaintBoardTouchManager.h"
#import "MFBezierCurvesTool.h"

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
    
    CGPoint point = [[touches anyObject] locationInView: _attachingView];
    
    [self.delegate onPointsOut: [self verticesFromPoints: @[@(point)]]];
    
    _from = point;
}

- (void)onTouchMovedOrEnded: (NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (![self checkDelegate]) return;
    
    UITouch *currentTouch = [touches anyObject];
    CGPoint previousPoint = [currentTouch previousLocationInView: _attachingView];
    CGPoint currentPoint = [currentTouch locationInView: _attachingView];
    
    CGPoint from = _from;
    CGPoint to = MiddlePoint(previousPoint, currentPoint);
    CGPoint control = previousPoint;
    
    if (CGPointEqualToPoint(_from, currentPoint)) return;
    
    CGFloat pointSize = [self.delegate currentPointSize];
    
    NSMutableArray *points = BezierPoints(from, to, control, pointSize);
    [points removeObjectAtIndex: 0]; // 移除首个，避免重复
    
    [self.delegate onPointsOut: [self verticesFromPoints: points.copy]];
    
    _from = to;
}

- (NSArray<NSValue *> *)verticesFromPoints: (NSArray<NSValue *> *)points {
    
    NSMutableArray *mVertices = [NSMutableArray array];
    for (NSValue *pv in points) {
        CGPoint p = pv.CGPointValue;
        
        CGPoint vertice = CGPointMake(p.x / CGRectGetWidth(_attachingView.frame) * 2 - 1,
                                      (p.y / CGRectGetHeight(_attachingView.frame) * 2 - 1) * -1);
        [mVertices addObject: [NSValue valueWithCGPoint: vertice]];
    }
    return mVertices.copy;
}

- (bool)checkDelegate {
    return (self.delegate &&
            [self.delegate respondsToSelector: @selector(onPointsOut:)] &&
            [self.delegate respondsToSelector: @selector(currentPointSize)]);
}

@end
