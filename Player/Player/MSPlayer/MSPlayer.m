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
#import <MediaPlayer/MediaPlayer.h>

CGFloat const MSPlayerHideControlViewDelay = 3; // 延迟隐藏播放器控制界面时间
CGFloat const MSPlayerHideHintViewDelay = 1;    // 延迟隐藏快进快退/亮度/音量时间

@interface MSPlayer ()

@property (nonatomic, strong) id                  playTimeObserver;     // 观察视频播放进度
@property (nonatomic, assign) BOOL                isFullScreen;         // 是否全屏
@property (nonatomic, assign) BOOL                isSliding;            // 是否正在滑动进度条
@property (nonatomic, assign) BOOL                isPanHorizontalMoved; // 是否横向滑动
@property (nonatomic, assign) BOOL                isBrightness;         // 是否是调节亮度
@property (nonatomic, assign) CGRect              originFrame;          // 父视图原始frame
@property (nonatomic, assign) CGFloat             totoalSeconds;        // 视频总长度
@property (nonatomic, assign) CGFloat             sumTime;              // 前进/后退的时间
@property (nonatomic, strong) AVPlayer            *player;              // 播放器
@property (nonatomic, strong) AVPlayerItem        *playerItem;          // 视频item
@property (nonatomic, strong) AVPlayerLayer       *playerLayer;         // 播放器layer
@property (nonatomic, strong) MSPlayerControlView *controlView;         // 播放器界面
@property (nonatomic, strong) MPVolumeView        *volumeView;          // 系统音量提示框
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;   // 加载提示

@end

@implementation MSPlayer

#pragma mark- 开始播放视频

// 播放地址
- (void)setUrl:(NSURL *)url {
    self.playerItem = [AVPlayerItem playerItemWithURL:url];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.backgroundColor = [UIColor blackColor].CGColor;
    self.playerLayer.frame = self.bounds;
    [self.layer addSublayer: self.playerLayer];
    [self addSubview:self.indicatorView];
    
    [self monitoringPlayback:self.playerItem]; // 监听播放
    [self addNotification]; // 添加通知
}

// 视频标题
- (void)setVideoTitle:(NSString *)videoTitle {
    self.controlView.videoTitleLabel.text = videoTitle;
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

// 添加观察者
- (void)addNotification {
    // 播放完毕
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFinished) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    // 进入前台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
    // 进入后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
    // 音量改变
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    // 屏幕旋转
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    // 观察播放状态
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
}

// 播放完毕
- (void)playFinished {
    [self shrinkFullScreen];
    if (self.playFinishedBlock) {
        self.playFinishedBlock();
    }
}

// 进入前台
- (void)enterForegroundNotification {

}

// 进入后台
- (void)enterBackgroundNotification {
    [self pause];
    
}

// 媒体音量变化
- (void)volumeChanged:(NSNotification *)noti {
    if ([noti.userInfo[@"AVSystemController_AudioCategoryNotificationParameter"]isEqualToString:@"Audio/Video"]) {
        CGFloat volume = [noti.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
        [self cancelSelector:@selector(hideVolumeView)];
        self.controlView.volumeView.hidden = NO;
        self.controlView.brightnessView.hidden = YES;
        self.controlView.volumePercentLabel.text = [NSString stringWithFormat:@"%.0f%%",volume*100];
        [self performSelector:@selector(hideVolumeView) withObject:nil afterDelay:1];
    }
}

// 屏幕旋转
- (void)deviceOrientationChange:(NSNotification*)noti{
    UIDeviceOrientation interfaceOrientation = [UIDevice currentDevice].orientation;
    if (interfaceOrientation == UIDeviceOrientationPortrait || interfaceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        //竖屏
        [self shrinkFullScreen];
        
    }else if (interfaceOrientation == UIDeviceOrientationLandscapeLeft || interfaceOrientation == UIDeviceOrientationLandscapeRight) {
        //横屏
        [self fullScreen];
    }
}


// 观察者
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            // 已经可以播放，添加播放器界面，开始播放
            [self.indicatorView stopAnimating];
            [self addControlView];
            self.totoalSeconds = CMTimeGetSeconds(self.playerItem.asset.duration);
            self.controlView.totalTimeLabel.text = [self stringFromSecond:self.totoalSeconds];
            [self play];
        }
    }
}

// 隐藏音量提示框
- (void)hideVolumeView {
    self.controlView.volumeView.hidden = YES;
}

// 开始播放
- (void)play {
    [self.player play];
    self.controlView.playButton.selected = YES;
}

// 暂停
- (void)pause {
    [self.player pause];
    self.controlView.playButton.selected = NO;
}

// 停止播放，调用此方法来移除播放器
- (void)stop {
    [self.player pause];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    [self.player removeTimeObserver:_playTimeObserver];
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    self.playTimeObserver = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self removeFromSuperview];
}

// 播放完毕block
- (void)playFinished:(playFinishedBlock)finishedBlock {
    self.playFinishedBlock = finishedBlock;
}

// 秒转成00:00格式字符串
- (NSString *)stringFromSecond:(NSInteger)second {
    if (second <= 60) {
        return [NSString stringWithFormat:@"00:%02ld",(long)second];
    }
    
    if (second <= 60*60) {
        NSInteger minutes = floor(second/60.0);
        NSInteger seconds = second%60;
        return [NSString stringWithFormat:@"%02ld:%02ld",(long)minutes,(long)seconds];
    }
    
    NSInteger hours = floor(second/3600.0);
    NSInteger minutes = floor((second-hours*3600)/60.0);
    NSInteger seconds = second%60;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hours,(long)minutes,(long)seconds];
}


#pragma mark- 初始化操作，添加播放器、设置播放器界面

// 添加播放器
- (void)addPlayerLayer {
    self.player = [[AVPlayer alloc]init];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.backgroundColor = [UIColor blackColor].CGColor;
    self.playerLayer.frame = self.bounds;
    [self.layer addSublayer: self.playerLayer];
}

// 添加播放器界面
- (void)addControlView {
    self.controlView = [[MSPlayerControlView alloc]initWithFrame:self.bounds];
    [self addControlViewEvents];
    [self addSubview:self.controlView];
    [self.controlView addSubview:self.volumeView]; // 隐藏系统音量框
    [self performSelector:@selector(hideControlView) withObject:nil afterDelay:MSPlayerHideControlViewDelay];
}

// 添加播放器界面事件
- (void)addControlViewEvents {
    [_controlView.playButton addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [_controlView.fullScreenButton addTarget:self action:@selector(fullScreenButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_controlView.backButton addTarget:self action:@selector(shrinkFullScreen) forControlEvents:UIControlEventTouchUpInside];
    [_controlView.progressSlider addTarget:self action:@selector(progressSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlView.progressSlider addTarget:self action:@selector(progressSliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [_controlView.progressSlider addTarget:self action:@selector(progressSliderTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(showOrHideControlView)];
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
        [self.controlView layoutSubviews];
    } completion:^(BOOL finished) {
        [self showControlView];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];

    }];
    
}

// 显示播放器控制界面
- (void)showControlView {
    [self cancelSelector:@selector(hideControlView)];
    self.controlView.videoControlTopView.hidden = NO;
    self.controlView.videoControlBottomView.hidden = NO;
    [self performSelector:@selector(hideControlView) withObject:nil afterDelay:MSPlayerHideControlViewDelay];
}

// 取消全屏/返回按钮
- (void)shrinkFullScreen {
    if (!self.isFullScreen) return;
    self.isFullScreen = NO;
    
    [self removeFromSuperview];
    [self.bgView addSubview:self];
    self.controlView.videoControlTopView.hidden = YES;
    [[UIApplication sharedApplication] setStatusBarHidden:NO];

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
    [self cancelSelector:@selector(hideControlView)];
}

// slider滑动结束开始播放
- (void)progressSliderTouchUpInside {
    self.isSliding = NO;
    [self play];
    [self performSelector:@selector(hideControlView) withObject:nil afterDelay:MSPlayerHideControlViewDelay];
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
- (void)showOrHideControlView {
    [self cancelSelector:@selector(hideControlView)];
    _controlView.videoControlBottomView.hidden = !_controlView.videoControlBottomView.hidden;
    if (self.isFullScreen) {
        _controlView.videoControlTopView.hidden = !_controlView.videoControlTopView.hidden;
    }
    
    [self performSelector:@selector(hideControlView) withObject:nil afterDelay:MSPlayerHideControlViewDelay];
}

// 隐藏播放器界面
- (void)hideControlView {
    self.controlView.videoControlBottomView.hidden = YES;
    self.controlView.videoControlTopView.hidden = YES;
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
                CGPoint locationPoint = [pan locationInView:self.controlView.gestureView];
                if (locationPoint.x < self.controlView.bounds.size.width/2) {
                    self.isBrightness = YES;
                }else {
                    self.isBrightness = NO;
                }
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
            
            [self performSelector:@selector(hideForwardView) withObject:nil afterDelay:MSPlayerHideHintViewDelay];
            [self performSelector:@selector(hideBrightnessView) withObject:nil afterDelay:MSPlayerHideHintViewDelay];
            
        }
            break;
            
        default:
            break;
    }
}

// 纵向滑动，调节亮度/音量
- (void)verticalMoved:(CGFloat)value {
    if (self.isBrightness) {
        [self cancelSelector:@selector(hideBrightnessView)];
        [UIScreen mainScreen].brightness -= value / (10000*3);
        self.controlView.brightnessView.hidden = NO;
        self.controlView.volumeView.hidden = YES;
        self.controlView.brightnessPercentLabel.text = [NSString stringWithFormat:@"%.0f%%",[UIScreen mainScreen].brightness*100];
    }else {
        MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
        #pragma clang diagnostic ignored"-Wdeprecated-declarations"
        mpc.volume -= value / (10000*3);
        
    }
}

// 横行滑动，调节快进快退
- (void)horizontalMoved:(CGFloat)value {
    [self pause];
    [self cancelSelector:@selector(hideForwardView)];
    self.controlView.forwardView.hidden = NO;
    if (value > 0) {
        self.controlView.forwardImageView.image = [UIImage imageNamed:@"msplayer_forward"];
    }else if (value < 0){
        self.controlView.forwardImageView.image = [UIImage imageNamed:@"msplayer_backward"];
    }else {
        return;
    }
    
    // 每次滑动需要叠加时间
    self.sumTime += value / (self.totoalSeconds/MSPlayerHideHintViewDelay);
    
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

// 隐藏亮度提示框
- (void)hideBrightnessView {
    self.controlView.brightnessView.hidden = YES;
}

// 隐藏前进/后退提示框
- (void)hideForwardView {
    self.controlView.forwardView.hidden = YES;
}

// 停止延迟执行某个方法
- (void)cancelSelector:(SEL)selector {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:nil];
}

// 系统音量提示框
- (MPVolumeView *)volumeView {
    if (!_volumeView) {
        _volumeView = [[MPVolumeView alloc]initWithFrame:CGRectMake(-1000, -1000, 0, 0)];
    }
    return _volumeView;
}

// 加载提示
- (UIActivityIndicatorView *)indicatorView {
    if (!_indicatorView) {
        _indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _indicatorView.center = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);;
        [_indicatorView startAnimating];
        _indicatorView.hidesWhenStopped = YES;
    }
    return _indicatorView;
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
