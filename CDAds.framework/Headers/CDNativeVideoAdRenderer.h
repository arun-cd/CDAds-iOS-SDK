//
//  CDNativeVideoAdRenderer.h
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CDNativeAdRenderer.h"

@class CDNativeAdRendererConfiguration;
@class CDStaticNativeAdRendererSettings;

@interface CDNativeVideoAdRenderer : NSObject

@property (nonatomic, readonly) CDNativeViewSizeHandler viewSizeHandler;

+ (CDNativeAdRendererConfiguration *)rendererConfigurationWithRendererSettings:(id<CDNativeAdRendererSettings>)rendererSettings;

@end
