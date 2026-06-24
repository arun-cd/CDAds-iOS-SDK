//
//  CDAdView.h
//  CDAds
//
//  Created by Arun Gupta on 07/01/18.
//  Copyright © 2019 Arun Gupta. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CDAdViewDelegate.h"

@interface CDAdView : UIView
@property (readonly) BOOL isInterstitialReady;
@property (weak, nonatomic) id<CDAdViewDelegate>delegate;
+ (CDAdView*)createAdViewWithDelegate:(id<CDAdViewDelegate>)delegate;
- (void)getAdWithNotification;
- (void)getAd;
- (void)getInterstitialAd;
- (void)displayInterstitial;
- (void)getInterstitialVideoAd;
- (void)getMRECVideoAd;
- (void)displayMrec;
@end
