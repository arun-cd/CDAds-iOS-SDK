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

