//
//  CDNativeAdRequest.h
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CDNativeAd;
@class CDNativeAdRequest;
@class CDNativeAdRequestTargeting;

typedef void(^CDNativeAdRequestHandler)(CDNativeAdRequest *request,
                                      CDNativeAd *response,
                                      NSError *error);

////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The `CDNativeAdRequest` class is used to manage individual requests to the CDAds ad server for
 * native ads.
 *
 * @warning **Note:** This class is meant for one-off requests for which you intend to manually
 * process the native ad response. If you are using `CDTableViewAdPlacer` or
 * `CDCollectionViewAdPlacer` to display ads, there should be no need for you to use this class.
 */

@interface CDNativeAdRequest : NSObject

/** @name Targeting Information */

/**
 * An object representing targeting parameters that can be passed to the CDAds ad server to
 * serve more relevant advertising.
 */
@property (nonatomic, strong) CDNativeAdRequestTargeting *targeting;

/** @name Initializing and Starting an Ad Request */

/**
 * Initializes a request object.
 *
 * @param identifier The ad unit identifier for this request. An ad unit is a defined placement in
 * your application set aside for advertising. Ad unit IDs are created on the CDAds website.
 *
 * @param rendererConfigurations An array of CDNativeAdRendererConfiguration objects that control how
 * the native ad is rendered.
 *
 * @return An `CDNativeAdRequest` object.
 */
+ (CDNativeAdRequest *)requestWithAdUnitIdentifier:(NSString *)identifier rendererConfigurations:(NSArray *)rendererConfigurations;

/**
 * Executes a request to the CDAds ad server.
 *
 * @param handler A block to execute when the request finishes. The block includes as parameters the
 * request itself and either a valid CDNativeAd or an NSError object indicating failure.
 */
- (void)startWithCompletionHandler:(CDNativeAdRequestHandler)handler;

@end
