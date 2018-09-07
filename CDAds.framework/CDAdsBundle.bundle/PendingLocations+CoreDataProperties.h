//
//  PendingLocations+CoreDataProperties.h
//  
//
//  Created by Arun Gupta on 07/09/18.
//
//  This file was automatically generated and should not be edited.
//

#import "PendingLocations+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface PendingLocations (CoreDataProperties)

+ (NSFetchRequest<PendingLocations *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSString *horizontalaccuracy;
@property (nonatomic) float lat;
@property (nonatomic) float lon;
@property (nonatomic) int16_t provider;

@end

NS_ASSUME_NONNULL_END
