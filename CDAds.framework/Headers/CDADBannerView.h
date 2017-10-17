//
//  cdAdView.h
//  Chalkboard
//
//  Created by Arun Gupta on 15/09/15.
//  Copyright (c) 2015 Arun Gupta. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "CDAdSize.h"
#import "CDADRequest.h"
#import "CDADRequestError.h"

@class CDADBannerView;
@protocol CDADBannerViewDelegate
@optional
-(BOOL)cdView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType;
-(void)cdViewStoppedExecuting:(CDADBannerView *)bannerView;
-(void)cdAdNewtorkRequestStartedForcdAdView:(CDADBannerView *)bannerView;
-(void)cdAdNetworkRequestFinishedForcdAdView:(CDADBannerView *)bannerView;
-(void)cdAdViewPaused:(CDADBannerView *)bannerView;
-(void)cdAdViewResumed:(CDADBannerView *)bannerView;
-(void)cdAdViewStoppedExecuting:(CDADBannerView *)bannerView;
-(void)cdAdViewStartedExecuting:(CDADBannerView *)bannerView;
-(void)cdAdViewDidReceiveAd:(CDADBannerView *)bannerView;
-(void)cdAdViewWillLeaveApplication:(CDADBannerView *)bannerView;
-(void)cdAdView:(CDADBannerView *)bannerView
didFailToReceiveAdWithError:(CDADRequestError *)error;
-(BOOL)cdAdView:(CDADBannerView *)bannerView shouldChangeVisibility:(BOOL)visible;

@end


@interface CDADBannerView : UIWebView <UIWebViewDelegate>
@property (weak, nonatomic) UIViewController *rootViewController;
@property (nonatomic) CDAdSize cdAdSize;
@property (atomic) BOOL isExecuting;
@property (readonly, strong, nonatomic) CDADRequest *adRequest;
@property (weak, nonatomic) NSObject<CDADBannerViewDelegate> *cdAdBannerViewDelegate;
@property (nonatomic) BOOL adAutoRefreshEnabled;
@property (nonatomic) NSTimeInterval refreshInterval;
@property (nonatomic) BOOL isExecutingNetworkRequest;
@property (readonly, strong, nonatomic) NSString *adtype;
-(void)stoppedExecuting;
-(void)loadRequest:(CDADRequest*)request;
-(void)pauseAdRefresh;
-(void)resumeAdRefresh;
-(void)stopAdRefresh;
-(id)initWithAdSize:(CDAdSize)adSize origin:(CGPoint)origin;
@end
