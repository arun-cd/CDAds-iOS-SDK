//
//  PendingLocations+CoreDataProperties.m
//  
//
//  Created by Arun Gupta on 05/03/19.
//
//  This file was automatically generated and should not be edited.
//

#import "PendingLocations+CoreDataProperties.h"

@implementation PendingLocations (CoreDataProperties)

+ (NSFetchRequest<PendingLocations *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"PendingLocations"];
}

@dynamic altitude;
@dynamic connectiontype;
@dynamic dwelltime;
@dynamic epoctime;
@dynamic horizontalaccuracy;
@dynamic ipaddress;
@dynamic lat;
@dynamic lon;
@dynamic provider;
@dynamic speed;
@dynamic timezone;
@dynamic verticalaccuracy;

@end
