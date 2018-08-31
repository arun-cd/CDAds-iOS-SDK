//
//  CDADDefines.h
//  CDAds
//
//  Created by Arun Gupta on 18/12/16.
//  Copyright © 2016 Chalkdigital. All rights reserved.
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
