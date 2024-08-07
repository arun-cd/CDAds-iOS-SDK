//
//  CDNativeAdRenderer.h
//  CDAdsSDK
//
//  Copyright (c) 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CDNativeAdAdapter;
@protocol CDNativeAdRendererSettings;
@class CDNativeAdRendererConfiguration;

/**
 *  Provide an implementation of this handler for your renderer settings.
 *
 *  @param maximumWidth Max width of the ad expected to be rendered as.
 *
 *  @return Size of the view as rendered given the maximum width desired.
 */
typedef CGSize (^CDNativeViewSizeHandler)(CGFloat maximumWidth);

/**
 * The CDAds SDK has a concept of native ad renderer that allows you to render the ad however you want. It also gives you the
 * ability to expose configurable properties through renderer settings objects to the application that influence how you render
 * your native custom event's view.
 *
 * Your renderer should implement this protocol. Your renderer is responsible for rendering the network's ad data into a view
 * when `-retrieveViewWithAdapter:error:` is called. Your renderer will be asked to render the native ad if your renderer cdAdInfo
 * indicates that your renderer supports your specific native ad network.
 *
 * Finally, your renderer will live as long as the ad adapter so you may store data in your renderer if necessary.
 */
@protocol CDNativeAdRenderer <NSObject>

@required

/**
 * You must construct and return an CDNativeAdRendererConfiguration object specific for your renderer. You must
 * set all the properties on the cdAdInfo object.
 *
 * @param rendererSettings Application defined settings that you should store in the cdAdInfo object that you
 * construct.
 *
 * @return A cdAdInfo object that allows the CDAds SDK to instantiate your renderer with the application
 * settings and for the supported ad types.
 */
+ (CDNativeAdRendererConfiguration *)rendererConfigurationWithRendererSettings:(id<CDNativeAdRendererSettings>)rendererSettings;

/**
 * This is the init method that will be called when the CDAds SDK initializes your renderer.
 *
 * @param rendererSettings The renderer settings object that corresponds to your renderer.
 */
- (instancetype)initWithRendererSettings:(id<CDNativeAdRendererSettings>)rendererSettings;

/**
 * You must return a native ad view when `-retrieveViewWithAdapter:error:` is called. Ideally, you should create a native view
 * each time this is called as holding onto the view may end up consuming a lot of memory when many ads are being shown.
 * However, it is OK to hold a strong reference to the view if you must.
 *
 * @param adapter Your custom event's adapter class that contains the network specific data necessary to render the ad to
 * a view.
 * @param error If you can't construct a view for whatever reason, you must fill in this error object.
 *
 * @return If successful, the method will return a native view presenting the ad. If it
 * is unsuccessful at retrieving a view, it will return nil and create
 * an error object for the error parameter.
 */
- (UIView *)retrieveViewWithAdapter:(id<CDNativeAdAdapter>)adapter error:(NSError **)error;

@optional

/**
 * The viewSizeHandler is used to allow the app to configure its native ad view size
 * given a maximum width when using ad placer solutions. This is not called when the
 * app is manually integrating native ads.
 *
 * You should obtain the renderer's viewSizeHandler from the settings object in
 * `-initWithRendererSettings:`.
 */
@property (nonatomic, readonly) CDNativeViewSizeHandler viewSizeHandler;

/**
 * The CDAdsSDK will notify your renderer when your native ad's view has moved in
 * the hierarchy. superview will be nil if the native ad's view has been removed
 * from the view hierarchy.
 *
 * The view your renderer creates is attached to another view before being added
 * to the view hierarchy. As a result, the superview argument will not be the renderer's ad view's superview.
 *
 * @param superview The app's view that contains the native ad view. There is an
 * intermediate view between the renderer's ad view and the app's view.
 */
- (void)adViewWillMoveToSuperview:(UIView *)superview;

/**
 *
 * The CDAdsSDK will call this method when the user has tapped the ad and will
 * invoke the clickthrough action.
 *
 */
- (void)nativeAdTapped;

@end
