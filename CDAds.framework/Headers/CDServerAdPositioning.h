//
//  CDServerAdPositioning.h
//  CDAds
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import "CDAdPositioning.h"

/**
 * The `CDServerAdPositioning` class is a model that allows you to control the positions where
 * native cdertisements should appear within a stream. A server positioning object works in
 * conjunction with an ad placer, telling the ad placer that it should retrieve positioning
 * information from the CDAds ad server.
 *
 * Unlike `CDClientAdPositioning`, which represents hard-coded positioning information, a server
 * positioning object offers you the benefit of modifying your ad positions via the CDAds website,
 * without rebuilding your application.
 */

@interface CDServerAdPositioning : CDAdPositioning

/** @name Creating a Server Positioning Object */

/**
 * Creates and returns a server positioning object.
 *
 * When an ad placer is set to use server positioning, it will ask the CDAds ad server for the
 * positions where ads should be inserted into a given stream. These positioning values are
 * configurable on the CDAds website.
 *
 * @return The newly created positioning object.
 *
 * @see CDClientAdPositioning
 */
+ (instancetype)positioning;

@end
