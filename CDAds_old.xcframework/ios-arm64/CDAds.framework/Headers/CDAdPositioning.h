//
//  CDAdPositioning.h
//  CDAds
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CDAdPositioning : NSObject <NSCopying>

@property (nonatomic, assign) NSUInteger repeatingInterval;
@property (nonatomic, strong, readonly) NSMutableOrderedSet *fixedPositions;

@end
