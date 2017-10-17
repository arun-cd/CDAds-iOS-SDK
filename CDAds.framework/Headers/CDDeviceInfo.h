//
//  CDDeviceInfo.h
//  Glass-Example
//
//  Created by Arun Gupta on 13/07/16.
//  Copyright © 2016 rain. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface CDDeviceInfo : NSObject
@property (readonly, strong, nonatomic) NSString* ua;
@property (readonly, strong, nonatomic) NSNumber *dnt ;
@property (readonly, strong, nonatomic) NSNumber *lmt ;
@property (nonatomic, readonly) NSInteger devicetype;
@property (readonly, strong, nonatomic) NSString* make;
@property (readonly, strong, nonatomic) NSString* model;
@property (readonly, strong, nonatomic) NSString* os;
@property (readonly, strong, nonatomic) NSString* osv;
@property (readonly, strong, nonatomic) NSString* hwv;
@property (readonly) NSInteger h;
@property (readonly) NSInteger w;
@property (readonly) float pxratio;
@property (readonly, strong, nonatomic) NSNumber *js;
@property (readonly, strong, nonatomic) NSString* language;
@property (readonly, strong, nonatomic) NSString* carrier;
@property (nonatomic, readonly) NSInteger connectiontype;
@property (readonly, strong, nonatomic) NSString* idfa;
+(CDDeviceInfo*)deviceInfo;
@end
