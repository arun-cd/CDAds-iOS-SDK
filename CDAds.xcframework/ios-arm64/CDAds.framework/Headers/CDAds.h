    //
    //  CDAds.h
    //  CDAds
    //
    //  Created by Arun Gupta on 15/01/19.
    //  Copyright © 2019 Chalk Digital Inc. All rights reserved.
    //


#import "CDAdSize.h"
#import "CDADRequest.h"
#import "CDDeviceInfo.h"
#import "CDInitialisationParams.h"
#import "CDGeoInfo.h"
#import "CDAdSize.h"
#import <CoreLocation/CoreLocation.h>
#import "CDADDefines.h"
#import "CDAdView.h"
#import "CDAdViewDelegate.h"
#import "CDGlobal.h"
#import "CDADRequestError.h"
#import "CDStaticNativeAdRenderer.h"
#import "CDNativeAdRequest.h"
#import "CDClientAdPositioning.h"
#import "CDNativeAdRenderer.h"
#import "CDNativeAdError.h"
#import "CDNativeAdDelegate.h"
#import "CDNativeAdConstants.h"
#import "CDNativeAdRendererSettings.h"
#import "CDNativeAdRequestTargeting.h"
#import "CDAdPositioning.h"
#import "CDNativeAdRendererSettings.h"
#import "CDTableViewAdPlacer.h"
#import "CDStreamAdPlacer.h"
#import "CDNativeAdRendering.h"
#import "CDNativeAd.h"
#import "CDNativeVideoAdRendererSettings.h"
#import "CDServerAdPositioning.h"
#import "CDCollectionViewAdPlacer.h"
#import "CDNativeVideoAdRenderer.h"
#import "CDNativeAdRendererConfiguration.h"
#import "CDStaticNativeAdRendererSettings.h"

    //! Project version number for CDAds.
FOUNDATION_EXPORT double CDAdsVersionNumber;

    //! Project version string for CDAds.
FOUNDATION_EXPORT const unsigned char CDAdsVersionString[];

    // In this header, you should import all the public headers of your framework using statements like #import "PublicHeader.h>

#ifndef _CDAds_
#define _CDAds_
#endif

@protocol CDAdsDelegate
@optional
-(void)cdAdsDidUpdateLocation:(CLLocation *)location;
-(void)cdadsLocationServicesDidFailWithError:(NSError *)error;
-(void)cdadsNetworkReachabilityChanged:(NSString*)status;
-(void)cdAdsRefreshConsole;
@end


@interface CDAds : NSObject
@property (strong, nonatomic) NSObject<CDAdsDelegate>* cdAdsDelegate;
@property (readonly, strong, nonatomic) CDInitialisationParams *cdInitialisationParams;
@property (nonatomic) BOOL enableTracking;
@property (readonly) BOOL limitedTrackingEnabled;
+(CDAds*)initialiseWithParams:(CDInitialisationParams*)cdInitialisationParams launchOptions:(NSDictionary*)launchOptions enableTracking:(BOOL)enableTracking;
+(CDAds*)runningInstance;
-(void)performUpdateWithCompletionHandler:(void  (^)(UIBackgroundFetchResult))completionHandler;
@end

