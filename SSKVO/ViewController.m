//
//  ViewController.m
//  SSKVO
//
//  Created by xingling xu on 2020/2/25.
//  Copyright © 2020 xingling xu. All rights reserved.
//

#import "ViewController.h"
#import "SSPerson.h"
#import "NSObject+SSKVO.h"

@interface ViewController ()
@property (nonatomic, strong) SSPerson *person;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.person = [SSPerson new];
    [self.person ss_addObserver:self forKeyPath:@"name" options:SSKeyValueObservingOptionNew|SSKeyValueObservingOptionOld context:NULL];
}

- (void)ss_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"change is %@",change);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.person.name = @"haha";
}

- (void)dealloc {
    [self.person ss_removeObserver:self forKeyPath:@"name" context:NULL];
}


@end
