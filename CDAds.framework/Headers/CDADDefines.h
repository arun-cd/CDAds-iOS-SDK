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

typedef enum CDLogLevels{
    CDLogLevelNone,
    CDLogLevelDetail
}CDLogLevel;

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
