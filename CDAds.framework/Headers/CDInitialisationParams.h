//
//  CDInitialisationParams.h
//  Glass-Example
//
//  Created by Arun Gupta on 14/07/16.
//  Copyright © 2016Chalkdigital. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CDADDefines.h"

@interface CDInitialisationParams : NSObject

@property (strong, nonatomic, nonnull) NSString *partnerId;
@property (strong, nonatomic, nonnull) NSString *applicationIABCategory;
@property (strong, nonatomic, nonnull) NSString *partnerSecret;
@property CLLocationDistance distanceFilter;
@property NSTimeInterval locationUpdateInterval;
@property NSTimeInterval adLocationExpiryInterval;
@property CDLogLevel logLevel;
@property CDADProvider provider;
@property CDEnvironment environment;
@property Boolean showTrackingTerms;
@property Boolean clientHasUserTrackingPermission;
@end
