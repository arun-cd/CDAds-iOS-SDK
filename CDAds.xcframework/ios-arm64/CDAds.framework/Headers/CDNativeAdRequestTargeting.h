//
//  CDNativeAdRequestTargeting.h
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CLLocation;

/**
 * The `CDNativeAdRequestTargeting` class is used to attach targeting information to
 * `CDNativeAdRequest` objects.
 */

@interface CDNativeAdRequestTargeting : NSObject

/** @name Creating a Targeting Object */

/**
 * Creates and returns an empty CDNativeAdRequestTargeting object.
 *
 * @return A newly initialized CDNativeAdRequestTargeting object.
 */
+ (CDNativeAdRequestTargeting *)targeting;

/** @name Targeting Parameters */

/**
 * A string representing a set of keywords that should be passed to the CDAds ad server to receive
 * more relevant advertising.
 *
 * Keywords are typically used to target ad campaigns at specific user segments. They should be
 * formatted as comma-separated key-value pairs (e.g. "marital:single,age:24").
 *
 * On the CDAds website, keyword targeting options can be found under the "Advanced Targeting"
 * section when managing campaigns.
 */
@property (nonatomic, copy) NSString *keywords;

/**
 * A `CLLocation` object representing a user's location that should be passed to the CDAds ad server
 * to receive more relevant advertising.
 */
@property (nonatomic, copy) CLLocation *location;

/**
 * A set of defined strings that correspond to assets for the intended native ad
 * object. This set should contain only those assets that will be displayed in the ad.
 *
 * The CDAds ad server will attempt to only return the assets in desiredAssets.
 */
@property (nonatomic, strong) NSSet *desiredAssets;

@end
