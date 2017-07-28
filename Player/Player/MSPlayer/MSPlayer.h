//
//  MSPlayer.h
//  Player
//
//  Created by miss on 2017/7/26.
//  Copyright © 2017年 mukr. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^playFinishedBlock)();

@interface MSPlayer : UIView

// 视频地址
@property (nonatomic, strong) NSURL *url;

// 视频标题
@property (nonatomic, copy) NSString *videoTitle;

// 视频所在的view
@property (nonatomic, strong) UIView *bgView;

// 视频播放完毕block
@property (nonatomic, copy) playFinishedBlock playFinishedBlock;

// 开始播放
- (void)play;

// 暂停播放
- (void)pause;

// 停止播放，在需要释放player时调用此方法
- (void)stop;

// 视频播放完毕
- (void)playFinished:(playFinishedBlock)finishedBlock;

@end
