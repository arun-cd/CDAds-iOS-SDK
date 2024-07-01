//
//  CDADDefines.h
//  CDAds
//
//  Created by Arun Gupta on 18/01/19.
//  Copyright © 2019 Chalk Digital Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CDNetworkStatus             @"CDNetworkStatus"
#define CDNetworkStatusReachable    @"CDNetworkStatusReachable"
#define CDNetworkStatusNotReachable @"CDNetworkStatusNotReachable"
#define CDNetworkStatusUnknown      @"CDNetworkStatusUnknown"

typedef enum CDEnvironments{
    CDEnvironmentProduction,
    CDEnvironmentTest
}CDEnvironment;

typedef enum CDADProviders{
    CDADProviderChalk,
    CDADProviderGoogle,
    CDADProviderAdMarvel,
    CDADProviderAdColonyAurora,
    CDADProviderAmazon,
    CDADProviderChartboost,
    CDADProviderFacebook,
    CDADProviderInMobi,
    CDADProviderHeyzap,
    CDADProviderMillenial,
    CDADProviderVungle,
    CDADProviderVurve,
    CDADProviderUnityAds,
    CDADProviderYuMe
}CDADProvider;

//typedef enum CDADTypes{
//    CDADTypeUnknown = -1,
//    CDADTypeBanner = 0,
//    CDADTypeInterstitial = 1
//}CDADType;


typedef enum CDLogLevels
{
    CDLogLevelAll        = 0,
    CDLogLevelTrace        = 10,
    CDLogLevelDebug        = 20,
    CDLogLevelInfo        = 30,
    CDLogLevelWarn        = 40,
    CDLogLevelError        = 50,
    CDLogLevelFatal        = 60,
    CDLogLevelOff        = 70
} CDLogLevel;

typedef enum CDNativeAdDataTypes
{
    CDNativeAdDataTypeSponsored = 1,
    CDNativeAdDataTypeDescription = 2,
    CDNativeAdDataTypeRating = 3,
    CDNativeAdDataTypeLikes = 4,
    CDNativeAdDataTypeDownloads = 5,
    CDNativeAdDataTypePrice = 6,
    CDNativeAdDataTypeSalePrice = 7,
    CDNativeAdDataTypePhone = 8,
    CDNativeAdDataTypeAddress = 9,
    CDNativeAdDataTypeDescription2 = 10,
    CDNativeAdDataTypeDisplayUrl = 11,
    CDNativeAdDataTypeCtaText = 12,
    CDNativeAdDataTypeOther = 501
} CDNativeAdDataType;
