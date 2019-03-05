//
//  CDLogProvider.h
//  CDAds
//
//  Created by Arun Gupta on 07/01/19.
//  Copyright © 2019 Chalk Digital Inc. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifndef CD_ANIMATED
#define CD_ANIMATED YES
#endif

UIInterfaceOrientation CDInterfaceOrientation(void);
UIWindow *CDKeyWindow(void);
CGFloat CDStatusBarHeight(void);
CGRect CDApplicationFrame(void);
CGRect CDScreenBounds(void);
CGSize CDScreenResolution(void);
CGFloat CDDeviceScaleFactor(void);
NSDictionary *CDDictionaryFromQueryString(NSString *query);
NSString *CDSHA1Digest(NSString *string);
BOOL CDViewIsVisible(UIView *view);
BOOL CDViewIntersectsParentWindowWithPercent(UIView *view, CGFloat percentVisible);
NSString *CDResourcePathForResource(NSString *resourceName);
NSArray *CDConvertStringArrayToURLArray(NSArray *strArray);
////////////////////////////////////////////////////////////////////////////////////////////////////

/*
 * Availability constants.
 */

#define CD_IOS_2_0  20000
#define CD_IOS_2_1  20100
#define CD_IOS_2_2  20200
#define CD_IOS_3_0  30000
#define CD_IOS_3_1  30100
#define CD_IOS_3_2  30200
#define CD_IOS_4_0  40000
#define CD_IOS_4_1  40100
#define CD_IOS_4_2  40200
#define CD_IOS_4_3  40300
#define CD_IOS_5_0  50000
#define CD_IOS_5_1  50100
#define CD_IOS_6_0  60000
#define CD_IOS_7_0  70000
#define CD_IOS_8_0  80000
#define CD_IOS_9_0  90000

////////////////////////////////////////////////////////////////////////////////////////////////////

enum {
    CDInterstitialCloseButtonStyleAlwaysVisible,
    CDInterstitialCloseButtonStyleAlwaysHidden,
    CDInterstitialCloseButtonStyleAdControlled
};
typedef NSUInteger CDInterstitialCloseButtonStyle;

enum {
    CDInterstitialOrientationTypePortrait,
    CDInterstitialOrientationTypeLandscape,
    CDInterstitialOrientationTypeCurrent,
    CDInterstitialOrientationTypeAll
};
typedef NSUInteger CDInterstitialOrientationType;

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIDevice (CDAdditions)

- (NSString *)cd_hardwareDeviceName;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIApplication (CDAdditions)

// Correct way to hide/show the status bar on pre-ios 7.
- (void)cd_preIOS7setApplicationStatusBarHidden:(BOOL)hidden;
- (BOOL)cd_supportsOrientationMask:(UIInterfaceOrientationMask)orientationMask;
- (BOOL)cd_doesOrientation:(UIInterfaceOrientation)orientation matchOrientationMask:(UIInterfaceOrientationMask)orientationMask;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
// Optional Class Forward Def Protocols
////////////////////////////////////////////////////////////////////////////////////////////////////

@class CDAdInfo, CLLocation;

@protocol CDAdAlertManagerProtocol <NSObject>

@property (nonatomic, strong) CDAdInfo *adInfo;
@property (nonatomic, copy) CLLocation *location;
@property (nonatomic, weak) UIView *targetAdView;
@property (nonatomic, weak) id delegate;

- (void)beginMonitoringAlerts;
- (void)endMonitoringAlerts;
- (void)processAdAlertOnce;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
// Small alert wrapper class to handle telephone protocol prompting
////////////////////////////////////////////////////////////////////////////////////////////////////

@class CDTelephoneConfirmationController;

typedef void (^CDTelephoneConfirmationControllerClickHandler)(NSURL *targetTelephoneURL, BOOL confirmed);

@interface CDTelephoneConfirmationController : NSObject <UIAlertViewDelegate>

- (id)initWithURL:(NSURL *)url clickHandler:(CDTelephoneConfirmationControllerClickHandler)clickHandler;
- (void)show;

@end
