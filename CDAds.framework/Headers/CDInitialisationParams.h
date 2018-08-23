//
//  CDInitialisationParams.h
//  Glass-Example
//
//  Created by Arun Gupta on 14/07/16.
//  Copyright © 2016 rain. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CDADDefines.h"

@interface CDInitialisationParams : NSObject

@property (strong, nonatomic, nonnull) NSString *key;
@property (strong, nonatomic, nonnull) NSString *publisherId;
@property (strong, nonatomic, nonnull) NSString *secret;
@property (strong, nonatomic, nonnull) NSString *site;
@property (strong, nonatomic, nonnull) NSString *siteId;
@property (strong, nonatomic, nonnull) NSString *applicationIABCategory;
@property CLLocationDistance distanceFilter;
@property NSTimeInterval locationUpdateInterval;
@property NSTimeInterval adLocationExpiryInterval;
@property CDLogLevel logLevel;
@property CDADProvider provider;
@property CDEnvironment environment;
@property Boolean showTrackingTerms;
@property Boolean clientHasUserTrackingPermission;
@end
