#import "UADSConfigurationEndpointProvider.h"
#import "USRVSdkProperties.h"
#import "UADSJsonStorageKeyNames.h"
#import "USRVDevice.h"
#import "USRVStorageManager.h"

NSString *const kUnityServicesConfigVersionKey = @"UnityAdsConfigVersion";

NSString *const kDefaultConfigVersion = @"configv2";
NSString *const kChinaConfigHostNameBase = @"unityads.unitychina.cn";
NSString *const kDefaultConfigHostNameBase = @"unityads.unity3d.com";


@interface UADSConfigurationEndpointProvider ()
@property (nonatomic, strong) id<UADSPlistReader>plistReader;
@end

@implementation UADSConfigurationEndpointProvider
+ (instancetype)defaultProvider {
    return [self newWithPlistReader: [NSBundle mainBundle]];
}

+ (instancetype)newWithPlistReader: (id<UADSPlistReader>)plistReader {
    UADSConfigurationEndpointProvider *provider = [self new];

    provider.plistReader = plistReader;
    return provider;
}

- (NSString *)hostname {
    NSString *version = self.configVersion ? : kDefaultConfigVersion;

    return [self finalNameWithConfigName: version];
}

- (NSString *)configVersion {
    return [_plistReader uads_getStringValueForKey: kUnityServicesConfigVersionKey];
}

- (NSString *)finalNameWithConfigName: (NSString *)config {
    return [config stringByAppendingFormat: @".%@", self.configHostName];
}

- (NSString *)configHostName {
    return self.isChina ? kChinaConfigHostNameBase : kDefaultConfigHostNameBase;
}

- (BOOL)isChina {
    return [USRVSdkProperties isChinaLocale: [USRVDevice getNetworkCountryISO]];
}

@end
