////  TestAVFoundationAspectRatioViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/11.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "TestAVFoundationAspectRatioViewController.h"

#import <AVFoundation/AVFoundation.h>

@interface TestAVFoundationAspectRatioViewController ()

@end

@implementation TestAVFoundationAspectRatioViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    UIImage *img = [UIImage imageNamed: @"avatar.JPG"];
    
    UIView *container = [[UIView alloc] initWithFrame: CGRectMake(30, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    container.backgroundColor = [UIColor whiteColor];
    [self.view addSubview: container];
    
    // create
    UIImageView *imgv = [[UIImageView alloc] initWithFrame: CGRectMake(0, 0, img.size.width, img.size.height)];
    imgv.image = img;
    [self.view addSubview: imgv];
    
    CGRect rect = [self countRect_AspectFit_Manully: img.size toRect: container.frame];
//    rect = [self countRect_AVfoundation: img.size toRect: container.frame];
    rect = [self countRect_AspectFill_Manully: img.size toRect: self.view.bounds];
    imgv.frame = rect;
}

- (CGRect)countRect_AspectFit_Manully: (CGSize)fromSize toRect:(CGRect)toRect {
    
    CGSize toSize = toRect.size;
    
    CGFloat wRatio = toSize.width / fromSize.width;
    CGFloat hRatio = toSize.height / fromSize.height;
    
    CGFloat ratio = MIN(wRatio, hRatio);
    
    CGSize newSize = CGSizeApplyAffineTransform(fromSize, CGAffineTransformMakeScale(ratio, ratio));
    
    CGPoint offset = CGPointMake((toSize.width - newSize.width) / 2.f, (toSize.height - newSize.height) / 2.f);
    
    return CGRectMake(offset.x + toRect.origin.x, offset.y + toRect.origin.y, newSize.width, newSize.height);
}

- (CGRect)countRect_AspectFill_Manully: (CGSize)fromSize toRect:(CGRect)toRect {
    
    CGSize toSize = toRect.size;
    
    CGFloat wRatio = toSize.width / fromSize.width;
    CGFloat hRatio = toSize.height / fromSize.height;
    
    CGFloat ratio = MAX(wRatio, hRatio);
    
    CGSize newSize = CGSizeApplyAffineTransform(fromSize, CGAffineTransformMakeScale(ratio, ratio));
    
    CGPoint offset = CGPointMake((toSize.width - newSize.width) / 2.f, (toSize.height - newSize.height) / 2.f);
    
    return CGRectMake(offset.x + toRect.origin.x, offset.y + toRect.origin.y, newSize.width, newSize.height);
}

- (CGRect)countRect_AVfoundation: (CGSize)fromSize toRect:(CGRect)toRect {
    return AVMakeRectWithAspectRatioInsideRect(fromSize, toRect);
}

@end
