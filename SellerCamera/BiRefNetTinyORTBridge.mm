#import "BiRefNetTinyORTBridge.h"

#import "Vendor/ONNXRuntimeObjC/include/onnxruntime.h"

NSErrorDomain const BiRefNetTinyORTBridgeErrorDomain = @"BiRefNetTinyORTBridge";

@implementation BiRefNetTinyORTBridge

+ (BOOL)isRuntimeDependencyReadyWithError:(NSError * _Nullable __autoreleasing *)error {
    NSError *localError = nil;
    ORTEnv *env = [[ORTEnv alloc] initWithLoggingLevel:ORTLoggingLevelWarning error:&localError];
    if (!env) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorRuntimeDependencyUnavailable
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_env_create_failed",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return NO;
    }
    return YES;
}

+ (nullable NSData *)runTinyModelAtPath:(NSString *)modelPath
                        inputTensorData:(NSData *)inputTensorData
                             inputWidth:(NSInteger)inputWidth
                            inputHeight:(NSInteger)inputHeight
                    preferredOutputName:(nullable NSString *)preferredOutputName
                            outputWidth:(NSInteger * _Nullable)outputWidth
                           outputHeight:(NSInteger * _Nullable)outputHeight
                                  error:(NSError * _Nullable __autoreleasing *)error {
    if (inputWidth <= 0 || inputHeight <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorModelIOContractInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"tiny_ort_invalid_input_shape"
                                     }];
        }
        return nil;
    }

    const NSUInteger requiredInputBytes = (NSUInteger)(inputWidth * inputHeight * 3 * sizeof(float));
    if (inputTensorData.length < requiredInputBytes) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorTensorDataInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"tiny_ort_input_tensor_data_too_small"
                                     }];
        }
        return nil;
    }

    NSError *localError = nil;
    ORTEnv *env = [[ORTEnv alloc] initWithLoggingLevel:ORTLoggingLevelWarning error:&localError];
    if (!env) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorRuntimeDependencyUnavailable
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_env_create_failed",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    ORTSessionOptions *sessionOptions = [[ORTSessionOptions alloc] initWithError:&localError];
    if (!sessionOptions) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorSessionCreateFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_session_options_create_failed",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }
    [sessionOptions setIntraOpNumThreads:1 error:nil];
    [sessionOptions setGraphOptimizationLevel:ORTGraphOptimizationLevelAll error:nil];

    ORTSession *session = [[ORTSession alloc] initWithEnv:env
                                                modelPath:modelPath
                                           sessionOptions:sessionOptions
                                                    error:&localError];
    if (!session) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorSessionCreateFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_session_create_failed",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    NSArray<NSString *> *inputNames = [session inputNamesWithError:&localError];
    if (!inputNames || inputNames.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorModelIOContractInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_input_name_missing",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    NSArray<NSString *> *outputNames = [session outputNamesWithError:&localError];
    if (!outputNames || outputNames.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorModelIOContractInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_output_name_missing",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    NSString *inputName = inputNames.firstObject;
    NSString *selectedOutputName = outputNames.firstObject;
    if (preferredOutputName.length > 0 && [outputNames containsObject:preferredOutputName]) {
        selectedOutputName = preferredOutputName;
    }

    NSMutableData *inputTensor = [inputTensorData mutableCopy];
    ORTValue *inputValue = [[ORTValue alloc] initWithTensorData:inputTensor
                                                     elementType:ORTTensorElementDataTypeFloat
                                                           shape:@[@1, @3, @(inputHeight), @(inputWidth)]
                                                           error:&localError];
    if (!inputValue) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorTensorDataInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_input_tensor_create_failed",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    NSDictionary<NSString *, ORTValue *> *runOutputs =
        [session runWithInputs:@{inputName : inputValue}
                    outputNames:[NSSet setWithObject:selectedOutputName]
                     runOptions:nil
                          error:&localError];
    if (!runOutputs || runOutputs.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorInferenceFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_run_failed",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    ORTValue *outputValue = runOutputs[selectedOutputName] ?: runOutputs.allValues.firstObject;
    if (!outputValue) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorInferenceFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"onnxruntime_output_value_missing"
                                     }];
        }
        return nil;
    }

    ORTTensorTypeAndShapeInfo *tensorTypeInfo = [outputValue tensorTypeAndShapeInfoWithError:&localError];
    if (!tensorTypeInfo || tensorTypeInfo.shape.count < 2) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorModelIOContractInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_output_shape_invalid",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    NSArray<NSNumber *> *shape = tensorTypeInfo.shape;
    NSInteger inferredHeight = shape[shape.count - 2].integerValue;
    NSInteger inferredWidth = shape[shape.count - 1].integerValue;
    if (inferredHeight <= 0 || inferredWidth <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorModelIOContractInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"onnxruntime_output_hw_invalid"
                                     }];
        }
        return nil;
    }

    NSMutableData *tensorData = [outputValue tensorDataWithError:&localError];
    if (!tensorData) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorInferenceFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: localError.localizedDescription ?: @"onnxruntime_output_tensor_data_missing",
                                         NSUnderlyingErrorKey: localError ?: [NSNull null]
                                     }];
        }
        return nil;
    }

    const NSUInteger requiredOutputBytes = (NSUInteger)(inferredHeight * inferredWidth * sizeof(float));
    if (tensorData.length < requiredOutputBytes) {
        if (error) {
            *error = [NSError errorWithDomain:BiRefNetTinyORTBridgeErrorDomain
                                         code:BiRefNetTinyORTBridgeErrorTensorDataInvalid
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"onnxruntime_output_tensor_data_too_small"
                                     }];
        }
        return nil;
    }

    if (outputWidth) {
        *outputWidth = inferredWidth;
    }
    if (outputHeight) {
        *outputHeight = inferredHeight;
    }

    return [NSData dataWithBytes:tensorData.bytes length:requiredOutputBytes];
}

@end
