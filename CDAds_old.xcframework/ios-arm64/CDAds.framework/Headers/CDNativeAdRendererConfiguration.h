//
//  CDNativeAdRendererConfiguration.h
//  CDAdsSDK
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CDNativeAdRendererSettings;

/*
 * All native ads loaded with the CDAds SDK take a renderer cdAdInfo object. This object links
 * the necessary native ad objects together.
 *
 * The cdAdInfo stores the renderer settings that will eventually be used when initializing the
 * render class. Furthermore, the cdAdInfo indicates what custom events the renderer class supports
 * through the supportedCustomEvents property.
 */
@interface CDNativeAdRendererConfiguration : NSObject

/*
 * The settings that inform the ad renderer about how it should render the ad.
 */
@property (nonatomic, strong) id<CDNativeAdRendererSettings> rendererSettings;

/*
 * The renderer class used to render supported custom events.
 */
@property (nonatomic, assign) Class rendererClass;

/*
 * An array of custom event class names (as strings) that the renderClass can
 * render.
 */
@property (nonatomic, strong) NSArray *supportedCustomEvents;

@end
