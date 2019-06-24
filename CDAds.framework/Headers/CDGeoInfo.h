//
//  CDGeoInfo.h
//  Glass-Example
//
//  Created by Arun Gupta on 13/01/19.
//  Copyright © 2019Chalk Digital Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface CDGeoInfo : NSObject <NSCoding>
@property float lat;
@property float lon;
@property NSInteger type;
@property (strong, nonatomic, nonnull) NSString* countryCode;
@property (strong, nonatomic, nonnull) NSString* region;
@property (strong, nonatomic, nonnull) NSString* city;
@property (strong, nonatomic, nonnull) NSString* zip;
@property (strong, nonatomic, nonnull) NSString* streetAddress;
@property (strong, nonatomic, nonnull) NSString* subThoroughFare;
@property (strong, nonatomic, nonnull) NSString* haccuracy;
@property (nonatomic) NSInteger metroCode;
@end
