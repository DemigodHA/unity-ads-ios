#import "UADSConfigurationLoaderBuilder.h"
#import "USRVWebRequestFactory.h"
#import "USRVSDKMetrics.h"
#import "UADSConfigurationCRUDBase.h"
#import "USRVConfigurationRequestFactoryWithLogs.h"
#import "UADSHeaderBiddingTokenReaderBuilder.h"
#import "UADSConfigurationLegacyLoader.h"
#import "UADSConfigurationLoaderWithPrivacy.h"
#import "USRVStorageManager.h"
#import "UADSDeviceInfoReaderBuilder.h"
#import "USRVBodyURLEncodedCompressorDecorator.h"
#import "USRVDictionaryCompressorWithMetrics.h"
#import "UADSWebRequestFactorySwiftAdapter.h"
#import "UADSPrivacyLoaderWithMetrics.h"
#import "UADSConfigurationLoaderWithMetrics.h"

#import "UADSServiceProvider.h"

@interface UADSConfigurationLoaderBuilder ()
@property (nonatomic, strong) UADSConfigurationLoaderBuilderConfig config;
@property (nonatomic, strong) id<IUSRVWebRequestFactory> webRequestFactory;
@end

@implementation UADSConfigurationLoaderBuilder


+ (instancetype)newWithConfig: (UADSConfigurationLoaderBuilderConfig)config
         andWebRequestFactory: (id<IUSRVWebRequestFactory>)webRequestFactory
                 metricSender: (id<ISDKMetrics>)metricSender  {
    UADSConfigurationLoaderBuilder *builder = [self new];

    builder.metricsSender = metricSender;
    builder.config = config;
    builder.webRequestFactory = webRequestFactory;
    builder.metricsSender = metricSender;
    return builder;
}

- (id<UADSConfigurationLoader>)loader {
    id<UADSConfigurationLoader> loaderToReturn = self.baseStrategy;

    loaderToReturn = [self decorateWithSaving: loaderToReturn];
    return loaderToReturn;
}

- (id<UADSConfigurationLoader>)baseStrategy {
    id<UADSConfigurationLoader>mainLoader = self.mainLoader;

    mainLoader = [self decorateWithMetrics: mainLoader];
    mainLoader = [self decorateLoaderWithPrivacyIfNeed: mainLoader];
    return [UADSConfigurationLoaderStrategy newWithMainLoader: mainLoader
                                            andFallbackLoader: self.fallbackLoader
                                                 metricSender: self.metricsSender];
}

- (id<UADSConfigurationLoader>)decorateWithSaving: (id<UADSConfigurationLoader>)original {
    return [UADSConfigurationLoaderWithPersistence newWithOriginal: original
                                                          andSaver: self.configurationSaver];
}

- (id<UADSConfigurationLoader>)mainLoader {
    id<USRVInitializationRequestFactory> factory = [self getMainFactory];

    factory = [self addLoggerToFactory: factory];
    return [UADSConfigurationLoaderBase newWithFactory: factory];
}

- (id<UADSConfigurationLoader>)decorateWithMetrics: (id<UADSConfigurationLoader>)original {
    return [UADSConfigurationLoaderWithMetrics decorateOriginal: original
                                               andMetricsSender: _metricsSender
                                                retryInfoReader: _retryInfoReader];
}

- (id<UADSConfigurationLoader>)fallbackLoader {
    return [UADSConfigurationLegacyLoader newWithRequestFactory: self.webRequestFactory];
}

- (id<USRVInitializationRequestFactory>)getMainFactory {
    if (_mainRequestFactory) {
        return _mainRequestFactory;
    }

    return [self requestFactoryWithExtendedInfo: true];
}

- (id<USRVInitializationRequestFactory>)requestFactoryWithExtendedInfo: (BOOL)hasExtendedInfo {
    id<USRVDataCompressor>dataCompressor = [self dataCompressorWithMetrics: hasExtendedInfo];

    return [USRVInitializationRequestFactoryBase newWithDeviceInfoReader: [self deviceInfoReader: hasExtendedInfo]
                                                       andDataCompressor: dataCompressor
                                                          andBaseBuilder: self.urlBaseBuilder
                                                    andWebRequestFactory: _webRequestFactory
                                                        andFactoryConfig: self.config
                                                      andTimeStampReader: self.timeStampReader];
}

- (id<UADSDeviceInfoReader>)deviceInfoReader: (BOOL)extended {
    if (_deviceInfoReader) {
        return _deviceInfoReader;
    }

    UADSDeviceInfoReaderBuilder *builder = [UADSDeviceInfoReaderBuilder new];

    builder.metricsSender = _metricsSender;
    builder.selectorConfig = self.config;
    builder.extendedReader = extended;
    builder.privacyReader = self.privacyStorage;
    builder.logger = self.logger;
    builder.currentTimeStampReader = self.currentTimeStampReader;
    builder.gameSessionIdReader = self.gameSessionIdReader;
    return builder.defaultReader;
}

- (id<USRVInitializationRequestFactory>)addLoggerToFactory: (id<USRVInitializationRequestFactory>)factory {
    return [USRVConfigurationRequestFactoryWithLogs newWithOriginal: factory];
}

- (id<UADSConfigurationLoader>)decorateLoaderWithPrivacyIfNeed: (id<UADSConfigurationLoader>)loader {
    if (_config.isPrivacyRequestEnabled) {
        return [UADSConfigurationLoaderWithPrivacy newWithOriginal: loader
                                                  andPrivacyLoader: self.getMainPrivacyLoader
                                                andResponseStorage: self.privacyResponseStorage];
    }

    return loader;
}

- (id<UADSPrivacyResponseSaver, UADSPrivacyResponseReader>)privacyResponseStorage {
    if (!_privacyStorage) {
        _privacyStorage = [UADSPrivacyStorage new];
    }

    return _privacyStorage;
}

- (id<UADSPrivacyLoader>)getMainPrivacyLoader {
    if (!_privacyLoader) {
        id<USRVInitializationRequestFactory> factory = [self requestFactoryWithExtendedInfo: false];
        factory = [self addLoggerToFactory: factory];
        _privacyLoader = [UADSPrivacyLoaderBase newWithFactory: factory];
        _privacyLoader = [UADSPrivacyLoaderWithMetrics decorateOriginal: _privacyLoader
                                                       andMetricsSender: _metricsSender
                                                        retryInfoReader: _retryInfoReader];
    }

    return _privacyLoader;
}

- (id<USRVStringCompressor>)stringCompressorWithMetrics: (BOOL)collectMetrics   {
    if (_noCompression) {
        return nil;
    }

    id<USRVDataCompressor> dataCompressor = [self dataCompressorWithMetrics: collectMetrics];
    id<USRVStringCompressor> compressor = [USRVBodyBase64GzipCompressor newWithDataCompressor: dataCompressor];

    compressor = [USRVBodyURLEncodedCompressorDecorator decorateOriginal: compressor];
    return compressor;
}

- (id<USRVDataCompressor>)dataCompressorWithMetrics: (BOOL)collectMetrics {
    id<USRVDataCompressor> dataCompressor = [USRVDataGzipCompressor new];

    if (collectMetrics) {
        dataCompressor = [USRVDictionaryCompressorWithMetrics decorateOriginal: dataCompressor
                                                              andMetricsSender: _metricsSender
                                                              currentTimestamp: _currentTimeStampReader];
    }

    return dataCompressor;
}

- (id<UADSBaseURLBuilder>)urlBaseBuilder {
    if (_urlBuilder) {
        return _urlBuilder;
    }

    id<UADSHostnameProvider>hostProvider = UADSConfigurationEndpointProvider.defaultProvider;

    return [UADSBaseURLBuilderBase newWithHostNameProvider: hostProvider];
}

- (id<UADSCurrentTimestamp>)timeStampReader {
    if (_currentTimeStampReader) {
        return _currentTimeStampReader;
    }

    return [UADSCurrentTimestampBase new];
}

@end
