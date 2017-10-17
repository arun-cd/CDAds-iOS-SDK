//
//  CDADController.h
//  CDADController
//
//  Created by Arun Gupta on 15/09/15.
//  Copyright (c) 2015 Arun Gupta. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CDADRequest.h"
#import "CDADBannerView.h"

@class CDADController;
@class CDADBannerView;
@protocol CDADControllerDelegate
@optional
-(void)cdViewStoppedExecuting:(CDADBannerView*)view;
-(void)cdAdNewtorkRequestStartedForcdAdViewForView:(CDADBannerView*)view;
-(void)cdAdNetworkRequestFinishedForcdAdViewForView:(CDADBannerView*)view;
@end



@interface CDADController : NSObject
@property (weak, nonatomic) NSObject<CDADControllerDelegate> *cdAdControllerDelegate;
+(CDADController*)getSharedController;
-(void)fetchNewAddForView:(CDADBannerView*)view;
-(void)networkrequestSuccessForView:(CDADBannerView*)view task:(NSURLSessionDataTask*)task request:(NSMutableURLRequest*)request responseObject:(id)responseObject;
-(NSMutableDictionary*)getParamsForView:(CDADBannerView*)view;
- (id) init __unavailable;

@end
