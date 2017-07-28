//
//  MSPlayerControlView.h
//  Player
//
//  Created by miss on 2017/7/26.
//  Copyright © 2017年 mukr. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MSPlayerControlView : UIView

@property (weak, nonatomic) IBOutlet UIView         *videoControlView;
@property (weak, nonatomic) IBOutlet UIView         *videoControlTopView;
@property (weak, nonatomic) IBOutlet UIView         *videoControlBottomView;
@property (weak, nonatomic) IBOutlet UIView         *gestureView;
@property (weak, nonatomic) IBOutlet UILabel        *videoTitleLabel;
@property (weak, nonatomic) IBOutlet UIButton       *playButton;
@property (weak, nonatomic) IBOutlet UISlider       *progressSlider;
@property (weak, nonatomic) IBOutlet UIButton       *fullScreenButton;
@property (weak, nonatomic) IBOutlet UIButton       *backButton;
@property (weak, nonatomic) IBOutlet UILabel        *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel        *totalTimeLabel;
@property (weak, nonatomic) IBOutlet UIView         *brightnessView;
@property (weak, nonatomic) IBOutlet UILabel        *brightnessPercentLabel;
@property (weak, nonatomic) IBOutlet UIView         *volumeView;
@property (weak, nonatomic) IBOutlet UILabel        *volumePercentLabel;
@property (weak, nonatomic) IBOutlet UIView         *forwardView;
@property (weak, nonatomic) IBOutlet UILabel        *forwardTimeLabel;
@property (weak, nonatomic) IBOutlet UIImageView    *forwardImageView;
@property (weak, nonatomic) IBOutlet UIProgressView *forwardProgressView;

@end
