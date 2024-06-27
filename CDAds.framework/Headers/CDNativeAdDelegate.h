//
//  CDNativeAdDelegate.h
//  CDAds
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

/**
 * The delegate of an `CDNativeAd` object must adopt the `CDNativeAdDelegate` protocol. It must
 * implement `viewControllerForPresentingModalView` to provide a root view controller from which
 * the ad view should present modal content.
 */
@class CDNativeAd;
@protocol CDNativeAdDelegate <NSObject>

@optional

/**
 * Sent when the native ad will present its modal content.
 *
 * @param nativeAd The native ad sending the message.
 */
- (void)willPresentModalForNativeAd:(CDNativeAd *)nativeAd;

/**
 * Sent when a native ad has dismissed its modal content, returning control to your application.
 *
 * @param nativeAd The native ad sending the message.
 */
- (void)didDismissModalForNativeAd:(CDNativeAd *)nativeAd;

/**
 * Sent when a user is about to leave your application as a result of tapping this native ad.
 *
 * @param nativeAd The native ad sending the message.
 */
- (void)willLeaveApplicationFromNativeAd:(CDNativeAd *)nativeAd;

@required

/** @name Managing Modal Content Presentation */

/**
 * Asks the delegate for a view controller to use for presenting modal content, such as the in-app
 * browser that can appear when an ad is tapped.
 *
 * @return A view controller that should be used for presenting modal content.
 */
- (UIViewController *)viewControllerForPresentingModalView;

@end
