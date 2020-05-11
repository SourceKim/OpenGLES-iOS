////  ViewController.m
//  OpenGLTest
//
//  Created by Su Jinjin on 2020/5/6.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView * table;

@property (nonatomic, copy) NSDictionary<NSString *, NSString *> * testMap;

@end

NSString * const kCellId = @"cellId";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table = [[UITableView alloc] initWithFrame: self.view.bounds style: UITableViewStylePlain];
    _table.delegate = self;
    _table.dataSource = self;
    [self.view addSubview: _table];
    
    [_table registerClass: [UITableViewCell class] forCellReuseIdentifier: kCellId];
    
    _testMap = @ {
        @"1. 三角形": @"TriangleViewController",
        @"2. 画一张图片": @"DrawImageViewController",
        @"3.1. 纹理详解 - AVMakeRectWithAspectRatioInsideRect": @"TestAVFoundationAspectRatioViewController",
    };
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: kCellId];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: kCellId];
    }
    
    cell.textLabel.text = [[_testMap allKeys] objectAtIndex: indexPath.item];
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_testMap allKeys].count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *vcName = [[_testMap allValues] objectAtIndex: indexPath.item];
    [self.navigationController pushViewController: [NSClassFromString(vcName) new] animated:true];
}

@end
