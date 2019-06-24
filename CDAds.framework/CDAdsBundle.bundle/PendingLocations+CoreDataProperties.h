//
//  PendingLocations+CoreDataProperties.h
//  
//
//  Created by Arun Gupta on 05/03/19.
//
//  This file was automatically generated and should not be edited.
//

#import "PendingLocations+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface PendingLocations (CoreDataProperties)

+ (NSFetchRequest<PendingLocations *> *)fetchRequest;

@property (nonatomic) double altitude;
@property (nonatomic) int16_t connectiontype;
@property (nonatomic) double dwelltime;
@property (nonatomic) int64_t epoctime;
@property (nonatomic) double horizontalaccuracy;
@property (nullable, nonatomic, copy) NSString *ipaddress;
@property (nonatomic) double lat;
@property (nonatomic) double lon;
@property (nonatomic) int16_t provider;
@property (nonatomic) double speed;
@property (nullable, nonatomic, copy) NSString *timezone;
@property (nonatomic) double verticalaccuracy;

@end

NS_ASSUME_NONNULL_END
