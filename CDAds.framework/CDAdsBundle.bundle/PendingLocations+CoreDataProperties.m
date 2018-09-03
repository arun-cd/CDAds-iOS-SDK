//
//  PendingLocations+CoreDataProperties.m
//  
//
//  Created by Arun Gupta on 03/09/18.
//
//  This file was automatically generated and should not be edited.
//

#import "PendingLocations+CoreDataProperties.h"

@implementation PendingLocations (CoreDataProperties)

+ (NSFetchRequest<PendingLocations *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"PendingLocations"];
}

@dynamic date;
@dynamic horizontalaccuracy;
@dynamic lat;
@dynamic lon;
@dynamic provider;

@end
