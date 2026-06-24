//
//  CDNativeAdError.h
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum CDNativeAdErrorCode {
    CDNativeAdErrorUnknown = -1,

    CDNativeAdErrorHTTPError = -1000,
    CDNativeAdErrorInvalidServerResponse = -1001,
    CDNativeAdErrorNoInventory = -1002,
    CDNativeAdErrorImageDownloadFailed = -1003,
    CDNativeAdErrorAdUnitWarmingUp = -1004,
    CDNativeAdErrorVASTParsingFailed = -1005,
    CDNativeAdErrorVideoConfigInvalid = -1006,

    CDNativeAdErrorContentDisplayError = -1100,
    CDNativeAdErrorRenderError = -1200
} CDNativeAdErrorCode;

extern NSString * const CDAdsNativeAdsSDKDomain;

NSError *CDNativeAdNSErrorForInvalidAdServerResponse(NSString *reason);
NSError *CDNativeAdNSErrorForAdUnitWarmingUp(void);
NSError *CDNativeAdNSErrorForNoInventory(void);
NSError *CDNativeAdNSErrorForNetworkConnectionError(void);
NSError *CDNativeAdNSErrorForInvalidImageURL(void);
NSError *CDNativeAdNSErrorForImageDownloadFailure(void);
NSError *CDNativeAdNSErrorForContentDisplayErrorMissingRootController(void);
NSError *CDNativeAdNSErrorForContentDisplayErrorInvalidURL(void);
NSError *CDNativeAdNSErrorForVASTParsingFailure(void);
NSError *CDNativeAdNSErrorForVideoConfigInvalid(void);
NSError *CDNativeAdNSErrorForRenderValueTypeError(void);
