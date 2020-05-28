//
//  MFBezierCurvesTool.h
//  GLPaintViewDemo
//
//  Created by Lyman Li on 2019/9/25.
//  Copyright © 2019年 Lyman Li. All rights reserved.
//

#import <UIKit/UIKit.h>

#define MiddlePoint(p1, p2) __MiddlePoint(p1, p2)

#define BezierPoints(from, to, control, pointSize) [MFBezierCurvesTool pointsWithFrom: from to: to control: control pointSize: pointSize]

static inline CGPoint __MiddlePoint(CGPoint point1, CGPoint point2) {
    return CGPointMake((point1.x + point2.x) / 2, (point1.y + point2.y) / 2);
}

@interface MFBezierCurvesTool : NSObject

/**
 通过二次贝塞尔曲线的三个关键点，计算点序列

 @param from 起始点
 @param to 终止点
 @param control 控制点
 @param pointSize 画笔尺寸，用于计算生成点的数量
 @return 点序列
 */
+ (NSMutableArray <NSValue *>*)pointsWithFrom:(CGPoint)from
                                           to:(CGPoint)to
                                      control:(CGPoint)control
                                    pointSize:(CGFloat)pointSize;

@end
