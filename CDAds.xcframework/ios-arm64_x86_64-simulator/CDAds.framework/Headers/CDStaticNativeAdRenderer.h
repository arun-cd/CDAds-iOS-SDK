//
//  CDStaticNativeAdRenderer.h
//  CDAdsSDK
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CDNativeAdRenderer.h"

@class CDNativeAdRendererConfiguration;
@class CDStaticNativeAdRendererSettings;

@interface CDStaticNativeAdRenderer : NSObject <CDNativeAdRenderer>

@property (nonatomic, readonly) CDNativeViewSizeHandler viewSizeHandler;

+ (CDNativeAdRendererConfiguration *)rendererConfigurationWithRendererSettings:(id<CDNativeAdRendererSettings>)rendererSettings;

@end
