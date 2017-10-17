//
//  CDAdSize.h
//  Glass-Example
//
//  Created by Arun Gupta on 12/07/16.
//  Copyright © 2016 rain. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if __has_feature(nullability)  // Available starting in Xcode 6.3.
#define CDAD_NULLABLE_TYPE __nullable
#define CDAD_NONNULL_TYPE __nonnull
#define CDAD_NULLABLE nullable

#define CDAD_ASSUME_NONNULL_BEGIN NS_ASSUME_NONNULL_BEGIN
#define CDAD_ASSUME_NONNULL_END NS_ASSUME_NONNULL_END
#else
#define CDAD_NULLABLE_TYPE
#define CDAD_NONNULL_TYPE
#define CDAD_NULLABLE

#define CDAD_ASSUME_NONNULL_BEGIN
#define CDAD_ASSUME_NONNULL_END
#endif  // __has_feature(nullability)

#if defined(__cplusplus)
#define CDAD_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define CDAD_EXTERN extern __attribute__((visibility("default")))
#endif  // defined(__cplusplus)

CDAD_ASSUME_NONNULL_BEGIN
typedef struct CDAdSize CDAdSize;

/// Ad size.
/// \see typedef CDAdSize
struct CDAdSize {
    CGSize size;       ///< The ad size. Don't modify this value directly.
};

#pragma mark Standard Sizes

/// iPhone, iPod and ipad Touch ad size. Typically 320x50.
CDAD_EXTERN CDAdSize const kCDAdSizeBanner320x50;

/// smaller width version of kGADAdSizeBanner320x50. Typically 300x100.
CDAD_EXTERN CDAdSize const kCDAdSizeBanner300x50;

/// Medium Rectangle size for the iPhone, iPod and ipad 300x250.
CDAD_EXTERN CDAdSize const kCDAdSizeBanner300x250;

CDAD_ASSUME_NONNULL_END
