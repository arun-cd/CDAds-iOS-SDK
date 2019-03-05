//
//  CDInitialisationParams.h
//  Glass-Example
//
//  Created by Arun Gupta on 14/01/19.
//  Copyright © 2019Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CDADDefines.h"

@interface CDInitialisationParams : NSObject

@property (strong, nonatomic, nonnull) NSString *partnerId;
@property (strong, nonatomic, nonnull) NSString *applicationIABCategory;
@property (strong, nonatomic, nonnull) NSString *partnerSecret;
@property (nonatomic) CLLocationDistance distanceFilter;
@property (nonatomic) NSTimeInterval locationUpdateInterval;
@property (nonatomic) NSTimeInterval adLocationExpiryInterval;
@property (nonatomic) CDLogLevel logLevel;
@property (nonatomic) CDADProvider provider;
@property (nonatomic) CDEnvironment environment;
@property (nonatomic) Boolean showTrackingTerms;
@property (nonatomic) Boolean gdpr;
@property (nonatomic) Boolean consent;
@property (readonly, nonatomic) Boolean geoIpLocationEnable;
@property (nonatomic) Boolean clientHasUserTrackingPermission;
@end
