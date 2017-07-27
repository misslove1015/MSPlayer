//
//  PlayViewController.m
//  Player
//
//  Created by miss on 2017/7/27.
//  Copyright © 2017年 mukr. All rights reserved.
//

#import "PlayViewController.h"
#import "MSPlayer.h"

@interface PlayViewController ()

@property (nonatomic, strong) MSPlayer *player;

@end

@implementation PlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.player = [[MSPlayer alloc]initWithFrame:CGRectMake(0, 64, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width*9/16)];
    [self.view addSubview:self.player];
    self.player.bgView = self.view;
    self.player.url = [NSURL URLWithString:@"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4"];
    [self.player play];
    [self.player playFinished:^{
        NSLog(@"播放完毕");
    }];
    
}

- (void)dealloc {
    [self.player stop];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
