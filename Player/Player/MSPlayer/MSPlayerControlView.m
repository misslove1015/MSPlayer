//
//  MSPlayerControlView.m
//  Player
//
//  Created by miss on 2017/7/26.
//  Copyright © 2017年 mukr. All rights reserved.
//

#import "MSPlayerControlView.h"

@implementation MSPlayerControlView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        NSArray *nibView = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil];
        UIView *view = [nibView objectAtIndex:0];
        view.frame = frame;
        self = (MSPlayerControlView *)view;
        [self.progressSlider setThumbImage:[UIImage imageNamed:@"msplayer_slider"] forState:UIControlStateNormal];
    }
    return self;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
