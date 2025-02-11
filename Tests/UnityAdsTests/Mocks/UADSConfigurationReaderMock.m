#import "NSDictionary+JSONString.h"
#import "UADSConfigurationReaderMock.h"

@implementation UADSConfigurationReaderMock

+ (instancetype)newWithMetricURL: (NSString *)metricURL {
    UADSConfigurationReaderMock *mock = [UADSConfigurationReaderMock new];

    mock.metricURL = metricURL;
    return mock;
}

+ (instancetype)newWithExperiments: (NSDictionary *)experiments {
    UADSConfigurationReaderMock *mock = [UADSConfigurationReaderMock new];

    mock.experiments = experiments;
    return mock;
}

- (nonnull USRVConfiguration *)getCurrentConfiguration {
    if (_expectedConfiguration) {
        return _expectedConfiguration;
    }

    NSMutableDictionary *configDictionary = [NSMutableDictionary dictionaryWithObject: @"fake-webview-url"
                                                                               forKey: @"url"];


    configDictionary[@"exp"] = self.experiments;
    configDictionary[@"murl"] = self.metricURL;

    return [[USRVConfiguration alloc] initWithConfigJsonData: configDictionary.uads_jsonData];
}

- (nonnull UADSConfigurationExperiments *)currentSessionExperiments {
    return [UADSConfigurationExperiments newWithJSON: self.experiments];
}


- (nonnull NSDictionary *)currentSessionExperimentsAsDictionary {
    return self.experiments;
}


- (NSDictionary *)metricTags {
    return self.experiments;
}

- (NSDictionary *)metricInfo {
    return self.experiments;
}


@end
