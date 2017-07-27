//
//  MSPlayer.m
//  Player
//
//  Created by miss on 2017/7/26.
//  Copyright © 2017年 mukr. All rights reserved.
//

#import "MSPlayer.h"
#import "MSPlayerControlView.h"
#import <AVFoundation/AVFoundation.h>

@interface MSPlayer ()

@property (nonatomic, strong) id                  playTimeObserver;     // 观察视频播放进度
@property (nonatomic, assign) BOOL                isFullScreen;         // 是否全屏
@property (nonatomic, assign) BOOL                isSliding;            // 是否正在滑动进度条
@property (nonatomic, assign) BOOL                isPanHorizontalMoved; // 是否横向滑动
@property (nonatomic, assign) CGRect              originFrame;          // 父视图原始frame
@property (nonatomic, assign) CGFloat             totoalSeconds;        // 视频总长度
@property (nonatomic, assign) CGFloat             sumTime;              // 前进/后退的时间
@property (nonatomic, strong) AVPlayer            *player;              // 播放器
@property (nonatomic, strong) AVPlayerItem        *playerItem;          // 视频item
@property (nonatomic, strong) AVPlayerLayer       *playerLayer;         // 播放器layer
@property (nonatomic, strong) MSPlayerControlView *controlView;         // 播放器界面

@end

@implementation MSPlayer

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self addPlayerLayer];
        [self addControlView];
        
    }
    return self;
}

#pragma mark- 开始播放视频时的操作

- (void)setUrl:(NSURL *)url {
    self.playerItem = [AVPlayerItem playerItemWithURL:url];
    [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    
    self.totoalSeconds = CMTimeGetSeconds(self.playerItem.asset.duration);
    self.controlView.totalTimeLabel.text = [self stringFromSecond:self.totoalSeconds];
    
    [self monitoringPlayback:self.playerItem]; // 监听播放
    [self addNotification]; // 添加通知
}


// 观察播放进度
- (void)monitoringPlayback:(AVPlayerItem *)item {
    __weak typeof(self)weakSelf = self;
    // 播放进度，每秒调用一次
    self.playTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        
        // 设置当前播放时间和slider
        NSInteger currentPlayTime = (double)item.currentTime.value/item.currentTime.timescale;
        weakSelf.controlView.currentTimeLabel.text = [weakSelf stringFromSecond:currentPlayTime];
        if (!weakSelf.isSliding) {
            weakSelf.controlView.progressSlider.value = currentPlayTime/self.totoalSeconds;
        }
        
    }];
}

- (void)addNotification {
    // 播放完毕
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFinished) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    // 进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
    // 进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)playFinished {
    if (self.playFinishedBlock) {
        self.playFinishedBlock();
    }
}

- (void)enterForegroundNotification {
    NSLog(@"进入前台");
    // [self play];
}

- (void)enterBackgroundNotification {
    NSLog(@"进入后台");
    [self pause];
    
}

- (void)play {
    [self.player play];
    self.controlView.playButton.selected = YES;
}

- (void)pause {
    [self.player pause];
    self.controlView.playButton.selected = NO;
    
}

- (void)stop {
    [self.player pause];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [self.player removeTimeObserver:_playTimeObserver];
    self.playTimeObserver = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeFromSuperview];
}

- (void)playFinished:(playFinishedBlock)finishedBlock {
    self.playFinishedBlock = finishedBlock;
}

- (NSString *)stringFromSecond:(NSInteger)second {
    if (second <= 60) {
        return [NSString stringWithFormat:@"00:%02ld",second];
    }
    
    if (second <= 60*60) {
        NSInteger minutes = floor(second/60.0);
        NSInteger seconds = second%60;
        return [NSString stringWithFormat:@"%02ld:%02ld",minutes,seconds];
    }
    
    NSInteger hours = floor(second/3600.0);
    NSInteger minutes = floor((second-hours*3600)/60.0);
    NSInteger seconds = second%60;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",hours,minutes,seconds];
}


#pragma mark- 初始化操作，添加播放器、设置播放器界面

- (void)addPlayerLayer {
    self.player = [[AVPlayer alloc]init];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.bounds;
    self.playerLayer.backgroundColor = [UIColor whiteColor].CGColor;
    [self.layer addSublayer: self.playerLayer];
}

- (void)addControlView {
    self.controlView = [[MSPlayerControlView alloc]initWithFrame:self.bounds];
    [self addControlViewEvents];
    [self addSubview:self.controlView];
}

- (void)addControlViewEvents {
    [_controlView.playButton addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [_controlView.fullScreenButton addTarget:self action:@selector(fullScreenButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_controlView.backButton addTarget:self action:@selector(shrinkFullScreen) forControlEvents:UIControlEventTouchUpInside];
    [_controlView.progressSlider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlView.progressSlider addTarget:self action:@selector(progressSliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [_controlView.progressSlider addTarget:self action:@selector(progressSliderTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapGestureView)];
    [_controlView.gestureView addGestureRecognizer:tap];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
    [_controlView.gestureView addGestureRecognizer:pan];
    
}

// 播放按钮
- (void)playButtonClick:(UIButton *)button {
    if (button.isSelected) {
        [self pause];
    }else {
        [self play];
    }
}

// 全屏按钮
- (void)fullScreenButtonClick {
    if (self.isFullScreen) {
        [self shrinkFullScreen];
    }else {
        [self fullScreen];
    }
}

// 全屏
- (void)fullScreen {
    if (self.isFullScreen) return;
    self.isFullScreen = YES;
    
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    [keyWindow addSubview:self];
    self.originFrame = self.frame;
    
    [UIView animateWithDuration:0.3f animations:^{
        self.bounds = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
        self.center = keyWindow.center;
        self.playerLayer.frame = self.bounds;
        self.transform = CGAffineTransformMakeRotation(M_PI_2);
        self.controlView.frame = self.bounds;
    } completion:^(BOOL finished) {
        self.controlView.videoControlTopView.hidden = NO;
        
    }];
    
}

// 取消全屏/返回按钮
- (void)shrinkFullScreen {
    if (!self.isFullScreen) return;
    self.isFullScreen = NO;
    
    [self removeFromSuperview];
    [self.bgView addSubview:self];
    self.controlView.videoControlTopView.hidden = YES;
    
    [UIView animateWithDuration:0.3f animations:^{
        [self setTransform:CGAffineTransformIdentity];
        self.frame = self.originFrame;
        self.playerLayer.frame = self.bounds;
        self.controlView.frame = self.bounds;
    } completion:^(BOOL finished) {
        
    }];
    
}

// slider被按下去时暂停播放
- (void)progressSliderTouchDown {
    [self pause];
}

// slider滑动结束开始播放
- (void)progressSliderTouchUpInside {
    self.isSliding = NO;
    [self play];
}

// 滑动slider
- (void)progressSliderValueChanged:(UISlider *)slider {
    self.isSliding = YES;
    [self pause];
    
    CMTime changedTime = CMTimeMakeWithSeconds(slider.value*self.totoalSeconds, 1.0);
    [self.playerItem seekToTime:changedTime completionHandler:^(BOOL finished) {
        // 跳转完成后做某事
    }];
}

// 点击视频隐藏或显示控制view
- (void)tapGestureView {
    _controlView.videoControlBottomView.hidden = !_controlView.videoControlBottomView.hidden;
    if (self.isFullScreen) {
        _controlView.videoControlTopView.hidden = !_controlView.videoControlTopView.hidden;
    }
    
}

// 滑动手势
- (void)panDirection:(UIPanGestureRecognizer *)pan {
    CGPoint veloctyPoint = [pan velocityInView:self.controlView.gestureView];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { //横向移动
                CMTime time = self.player.currentTime;
                self.sumTime = time.value/time.timescale;
                self.isPanHorizontalMoved = YES;
                [self horizontalMoved:veloctyPoint.x];
                
            }else if (x < y){ //纵向移动
                self.isPanHorizontalMoved = NO;
                [self verticalMoved:veloctyPoint.y];
            }
        }
            break;
            
        case UIGestureRecognizerStateChanged:{
            if (self.isPanHorizontalMoved) {
                [self horizontalMoved:veloctyPoint.x];
                
            }else {
                [self verticalMoved:veloctyPoint.y];
            }
        }
            break;
            
        case UIGestureRecognizerStateEnded:{
            if (self.isPanHorizontalMoved) {
                [self horizontalMoved:veloctyPoint.x];
                [self play];
                self.sumTime = 0;
                
            }else {
                [self verticalMoved:veloctyPoint.y];
            }
            
            self.controlView.forwardView.hidden = YES;
            self.controlView.brightnessView.hidden = YES;
            
        }
            break;
            
        default:
            break;
    }
}

// 纵向滑动，调节屏幕了亮度
- (void)verticalMoved:(CGFloat)value {
    [UIScreen mainScreen].brightness -= value / 10000;
    self.controlView.brightnessView.hidden = NO;
    self.controlView.brightnessPercentLabel.text = [NSString stringWithFormat:@"%.0f%%",[UIScreen mainScreen].brightness*100];
}

// 横行滑动，调节快进快退
- (void)horizontalMoved:(CGFloat)value {
    [self pause];
    self.controlView.forwardView.hidden = NO;
    if (value > 0) {
        self.controlView.forwardImageView.image = [UIImage imageNamed:@"msplayer_forward"];
    }else {
        self.controlView.forwardImageView.image = [UIImage imageNamed:@"msplayer_backward"];
    }
    
    // 每次滑动需要叠加时间
    self.sumTime += value / self.totoalSeconds;
    
    // sumTime的范围
    if (self.sumTime > self.totoalSeconds) {
        self.sumTime = self.totoalSeconds;
    }else if (self.sumTime < 0) {
        self.sumTime = 0;
    }
    
    [self forwardOrBackward:self.sumTime];
    
}

//  前进/后退到某个时间
- (void)forwardOrBackward:(NSInteger)time {
    CGFloat percent = time/self.totoalSeconds;    
    self.controlView.currentTimeLabel.text = [self stringFromSecond:time];
    self.controlView.progressSlider.value = percent;
    self.controlView.forwardProgressView.progress = percent;
    self.controlView.forwardTimeLabel.text = [NSString stringWithFormat:@"%@ / %@", [self stringFromSecond:time], [self stringFromSecond:self.totoalSeconds]];
    CMTime changedTime = CMTimeMakeWithSeconds(self.controlView.progressSlider.value*self.totoalSeconds, 1.0);
    [self.playerItem seekToTime:changedTime completionHandler:^(BOOL finished) {
        // 跳转完成后做某事
    }];
}

- (void)dealloc {
    NSLog(@"player dealloc");
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
