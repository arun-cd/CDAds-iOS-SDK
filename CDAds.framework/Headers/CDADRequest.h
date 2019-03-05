//
//  CDADRequest.h
//
//  Created by Arun Gupta on 15/01/19.
//  Copyright (c) 2019 Arun Gupta. All rights reserved.
//
#import "CDDeviceInfo.h"
#import "CDGeoInfo.h"

@interface CDADRequest : NSObject
@property (strong, nonatomic, nonnull) NSString *targetingAge;
@property (strong, nonatomic, nonnull) NSString *targetingGender;
@property (strong, nonatomic, nonnull) NSString *targetingIncome;
@property (strong, nonatomic, nonnull) NSString *targetingEducation;
@property (strong, nonatomic, nonnull) NSString *targetingLanguage;
@property (strong, nonatomic, nonnull) NSString *keyword;
@property (strong, nonatomic, nonnull) NSString *placementId;
@property (strong, nonatomic, nonnull) NSString *partnerId;
@property (strong, readonly, nonatomic, nonnull) NSString *ver;
@property BOOL onlySecureImpressionsAllowed;
@property BOOL locationAutoUpdateEnabled;
@property (strong, nonatomic, nonnull) CDGeoInfo *geoInfo;
- (BOOL)isReady;
- ( NSMutableDictionary* _Nonnull )getParams;
@end
