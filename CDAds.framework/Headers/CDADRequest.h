//
//  CDADRequest.h
//  Chalkboard
//
//  Created by Arun Gupta on 15/09/15.
//  Copyright (c) 2015 Arun Gupta. All rights reserved.
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
@property (strong, readonly, nonatomic, nonnull) NSString *ver;
@property BOOL onlySecureImpressionsAllowed;
@property BOOL locationAutoUpdateEnabled;
@property (strong, nonatomic, nonnull) CDGeoInfo *geoInfo;
- (BOOL)isReady;
- ( NSMutableDictionary* _Nonnull )getParams;
@end
