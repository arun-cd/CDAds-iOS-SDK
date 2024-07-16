//
//  CDAdViewDelegate.h
//  CDAds
//
//  Created by Arun Gupta on 07/01/18.
//  Copyright © 2018 Arun Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CDGeoInfo.h"
@class CDAdView;
#import "CDAdSize.h"


@protocol CDAdViewDelegate <NSObject>

@required
- (NSString*)placementId:(CDAdView*)cdAdView;
- (NSString*)partnerId:(CDAdView*)cdAdView;
- (UIViewController *) applicationUIViewController:(CDAdView*)cdAdView;

@optional
- (CGRect) cdAdViewFrame:(CDAdView*)cdAdView;
- (CDAdSize) cdAdViewSize:(CDAdView*)cdAdView;
- (void) getAdSucceeded:(CDAdView*)cdAdView;
- (void) getAdFailed:(CDAdView*)cdAdView;
- (void) getMrecAdSucceeded:(CDAdView*)cdAdView;
- (void) getMrecAdFailed:(CDAdView*)cdAdView;
- (void) mrecActivated:(CDAdView*)cdAdView;
- (void) mrecCompleted:(CDAdView*)cdAdView;
- (void) getInterstitialAdSucceeded:(CDAdView*)cdAdView;
- (void) getInterstitialAdFailed:(CDAdView*)cdAdView;
- (void) interstitialActivated:(CDAdView*)cdAdView;
- (void) allMrecCompleted:(CDAdView*)cdAdView;
- (void) interstitialClosed:(CDAdView*)cdAdView;
- (NSDictionary*) targetingParameters:(CDAdView*)cdAdView;
- (UIColor*) textAdFontColor:(CDAdView*)cdAdView;
- (UIColor*) backgroundColor:(CDAdView*)cdAdView;
- (UIColor*) textAdBorderColor:(CDAdView*)cdAdView;
- (BOOL) locationServicesEnabled:(CDAdView*)cdAdView;
- (CDGeoInfo *) locationObject:(CDAdView*)cdAdView;
- (BOOL) useInAppBrowser:(CDAdView*)cdAdView;
- (void) interstitialWillAppear:(CDAdView*)cdAdView;
- (void) interstitialWillDisappear:(CDAdView*)cdAdView;
- (void) adViewWillLeaveApplication:(CDAdView*)cdAdView;
- (void) adViewDidReceiveTapEvent:(CDAdView*)cdAdView;
- (BOOL) allowUnsecuredImpressions:(CDAdView*)cdAdView;
- (BOOL) allowAutomaticRefreshAds:(CDAdView*)cdAdView;
- (BOOL) closeable:(CDAdView*)cdAdView;
@end

