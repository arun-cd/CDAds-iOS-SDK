//
//  CDNativeAdRendererSettings.h
//  CDAdsSDK
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CDNativeAdRenderer.h"

/*
 * Renderer settings are objects that allow you to expose configurable properties to the application.
 * You renderer will be initialized with these settings.
 *
 * You should create a renderer settings object that adheres to this protocol and exposes configurable
 * configurable properties for your renderer class.
 */
@protocol CDNativeAdRendererSettings <NSObject>

@optional

/**
 * The viewSizeHandler is used to allow the app to configure its native ad view size
 * given a maximum width when using ad placer solutions. This is not called when the
 * app is manually integrating native ads.
 *
 * Your renderer settings object should expose a settable viewSizeHandler property so the
 * application can choose how it wants to size its ad views. Your renderer will be able
 * to use the view size handler from your settings object.
 */
@property (nonatomic, readwrite, copy) CDNativeViewSizeHandler viewSizeHandler;

@end
