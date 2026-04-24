#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const BiRefNetTinyORTBridgeErrorDomain;

typedef NS_ENUM(NSInteger, BiRefNetTinyORTBridgeErrorCode) {
    BiRefNetTinyORTBridgeErrorRuntimeDependencyUnavailable = 1001,
    BiRefNetTinyORTBridgeErrorSessionCreateFailed = 1002,
    BiRefNetTinyORTBridgeErrorModelIOContractInvalid = 1003,
    BiRefNetTinyORTBridgeErrorInferenceFailed = 1004,
    BiRefNetTinyORTBridgeErrorTensorDataInvalid = 1005,
};

@interface BiRefNetTinyORTBridge : NSObject

+ (BOOL)isRuntimeDependencyReadyWithError:(NSError * _Nullable * _Nullable)error;

+ (nullable NSData *)runTinyModelAtPath:(NSString *)modelPath
                        inputTensorData:(NSData *)inputTensorData
                             inputWidth:(NSInteger)inputWidth
                            inputHeight:(NSInteger)inputHeight
                    preferredOutputName:(nullable NSString *)preferredOutputName
                            outputWidth:(NSInteger * _Nullable)outputWidth
                           outputHeight:(NSInteger * _Nullable)outputHeight
                                  error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
