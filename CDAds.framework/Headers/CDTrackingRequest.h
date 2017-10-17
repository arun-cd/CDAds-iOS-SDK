//
//  CDTrackingRequest.h
//  CDAds
//
//  Created by Arun Gupta on 15/07/16.
//  Copyright © 2016 Chalkdigital. All rights reserved.
//

#import "CDGeoInfo.h"

@interface CDTrackingRequest : NSObject
- (id _Nonnull) init __unavailable;
+(CDTrackingRequest* _Nonnull)trackingRequest;
-(NSMutableDictionary* _Nonnull)getParams;
@end
