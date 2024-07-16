    //
    //  CDAds.h
    //  CDAds
    //
    //  Created by Arun Gupta on 15/01/19.
    //  Copyright © 2019 Chalk Digital Inc. All rights reserved.
    //


#import <CDAds/CDAdSize.h>
#import <CDAds/CDADRequest.h>
#import <CDAds/CDDeviceInfo.h>
#import <CDAds/CDInitialisationParams.h>
#import <CDAds/CDGeoInfo.h>
#import <CDAds/CDAdSize.h>
#import <CoreLocation/CoreLocation.h>
#import <CDAds/CDADDefines.h>
#import <CDAds/CDAdView.h>
#import <CDAds/CDAdViewDelegate.h>
#import <CDAds/CDGlobal.h>
#import <CDAds/CDADRequestError.h>
#import <CDAds/CDStaticNativeAdRenderer.h>
#import <CDAds/CDNativeAdRequest.h>
#import <CDAds/CDClientAdPositioning.h>
#import <CDAds/CDNativeAdRenderer.h>
#import <CDAds/CDNativeAdError.h>
#import <CDAds/CDNativeAdDelegate.h>
#import <CDAds/CDNativeAdConstants.h>
#import <CDAds/CDNativeAdRendererSettings.h>
#import <CDAds/CDNativeAdRequestTargeting.h>
#import <CDAds/CDAdPositioning.h>
#import <CDAds/CDNativeAdRendererSettings.h>
#import <CDAds/CDTableViewAdPlacer.h>
#import <CDAds/CDStreamAdPlacer.h>
#import <CDAds/CDNativeAdRendering.h>
#import <CDAds/CDNativeAd.h>
#import <CDAds/CDNativeVideoAdRendererSettings.h>
#import <CDAds/CDServerAdPositioning.h>
#import <CDAds/CDCollectionViewAdPlacer.h>
#import <CDAds/CDNativeVideoAdRenderer.h>
#import <CDAds/CDNativeAdRendererConfiguration.h>
#import <CDAds/CDStaticNativeAdRendererSettings.h>

    //! Project version number for CDAds.
FOUNDATION_EXPORT double CDAdsVersionNumber;

    //! Project version string for CDAds.
FOUNDATION_EXPORT const unsigned char CDAdsVersionString[];

    // In this header, you should import all the public headers of your framework using statements like #import <CDAds/PublicHeader.h>

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

