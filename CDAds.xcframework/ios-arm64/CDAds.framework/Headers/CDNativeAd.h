//
//  CDNativeAd.h
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CDNativeAdAdapter;
@protocol CDNativeAdDelegate;
@protocol CDNativeAdRenderer;
@class CDAdInfo;
@class NativeAdData;

/**
 * The `CDNativeAd` class is used to render and manage events for a native cdertisement. The
 * class provides methods for accessing native ad properties returned by the server, as well as
 * convenience methods for URL navigation and metrics-gathering.
 */

@interface CDNativeAd : NSObject

@property (strong, nonatomic)NativeAdData *data;

/** @name Ad Resources */

/**
 * The delegate of the `CDNativeAd` object.
 */
@property (nonatomic, weak) id<CDNativeAdDelegate> delegate;

/**
 * A dictionary representing the native ad properties.
 */
@property (nonatomic, readonly) NSDictionary *properties;

- (instancetype)initWithAdAdapter:(id<CDNativeAdAdapter>)adAdapter;

/** @name Retrieving Ad View */

/**
 * Retrieves a rendered view containing the ad.
 *
 * @param error A pointer to an error object. If an error occurs, this pointer will be set to an
 * actual error object containing the error information.
 *
 * @return If successful, the method will return a view containing the rendered ad. The method will
 * return nil if it cannot render the ad data to a view.
 */
- (UIView *)retrieveAdViewWithError:(NSError **)error;

- (void)trackMetricForURL:(NSString *)URL;
- (void)displayAdContent;
@end
