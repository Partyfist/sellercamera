//
//  CaptureWhiteBackgroundProcessor.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/1.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import CoreVideo
import Foundation
import Vision

enum CaptureWhiteBackgroundProcessorError: LocalizedError {
    case unsupportedSystemVersion
    case invalidInputImage
    case subjectMaskUnavailable
    case segmentationModelUnavailable
    case segmentationInferenceFailed
    case outputCompositionFailed
    case outputEncodingFailed
    case segmentationModelContractMismatch
    case segmentationRuntimeDependencyUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedSystemVersion:
            return "当前系统版本不支持白底处理"
        case .invalidInputImage:
            return "输入图片不可用"
        case .subjectMaskUnavailable:
            return "未识别到可处理主体"
        case .segmentationModelUnavailable:
            return "分割模型资产不可用"
        case .segmentationInferenceFailed:
            return "分割推理失败"
        case .outputCompositionFailed:
            return "白底合成失败"
        case .outputEncodingFailed:
            return "处理结果编码失败"
        case .segmentationModelContractMismatch:
            return "当前分割模型输入/输出 contract 与 provider 不匹配"
        case .segmentationRuntimeDependencyUnavailable:
            return "当前运行环境未引入 ONNX Runtime iOS 依赖，tiny ORT provider 暂不可用"
        }
    }
}

struct CaptureWhiteBackgroundProcessor {
    private enum SegmentationProviderID: String {
        case vision
        case visionAttentionSaliency = "vision_attention_saliency"
        case visionObjectnessSaliency = "vision_objectness_saliency"
        case visionForegroundLatestRevision = "vision_foreground_latest_revision"
        case visionForegroundObjectnessHybrid = "vision_foreground_objectness_hybrid"
        case birefnet = "birefnet"
        case birefnetTinyORT = "birefnet_tiny_ort"
    }

    private enum SegmentationExperimentEnvironment {
        static let providerKey = "SELLERCAMERA_SEGMENTATION_PROVIDER"
        static let birefnetResourceKey = "SELLERCAMERA_BIREFNET_MODEL_RESOURCE"
        static let birefnetModelPathKey = "SELLERCAMERA_BIREFNET_MODEL_PATH"
        static let birefnetTinyORTModelPathKey = "SELLERCAMERA_BIREFNET_TINY_ORT_MODEL_PATH"
    }

    private enum BiRefNetConfig {
        static let defaultResourceName = "RMBG-2-native-int8"
        static let fallbackResourceNames = ["RMBG-2-native", "BiRefNetSegmentation", "BiRefNet", "birefnet"]
        static let track = "admission_candidate_birefnet_v1"
        static let preferredOutputFeatureName = "output_3"
        static let tinyORTTrack = "admission_candidate_birefnet_tiny_ort_v1"
        static let tinyORTDefaultModelPath = "ModelAssets/BiRefNet/onnx/BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx"
        static let tinyORTBundledModelFileName = "BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx"
        static let tinyORTInputWidth = 1024
        static let tinyORTInputHeight = 1024
    }

    private enum ProcessingConfig {
        enum Refinement {
            static let closedMaskMorphologyRadius = 1.1
            static let coreMaskRadius = 0.8
            static let expandedMaskRadius = 1.8
            static let edgeBandDetailBoostFactor: CGFloat = 0.42
            static let edgeTransitionBlurRadius = 0.26
            static let reflectiveTransitionBlurRadius = 1.25
            static let thinStructureBoostFactor: CGFloat = 0.24
            static let hardEdgeContinuityBlurRadius = 0.55
            static let hardEdgeStabilizedMaximumRadius = 0.62
            static let hardEdgeStabilizedMinimumRadius = 0.48
            static let finalEdgeBlurRadius = 0.08
            static let coreAnchorMinimumRadius = 0.2
            static let coreAnchorMaximumRadius = 0.45
            static let coreAnchorBlurRadius = 0.06
            static let deepCoreMinimumRadius = 0.62
            static let deepCoreBlurRadius = 0.04
            // R1.5: refinement phase-2 micro-tuning (low-risk, targeted on core_v1 hard spots)
            static let edgePreserveRegionBlurRadius = 0.3
            static let thinStructurePreserveBoostFactor: CGFloat = 0.2
            static let contactEdgeShiftY: CGFloat = 1.8
            static let contactEdgeSupportBlurRadius = 0.44
            static let contactEdgeSupportBoostFactor: CGFloat = 0.21
            static let nearWhiteCoreThreshold: CGFloat = 0.73
            static let nearWhiteCoreBlurRadius = 0.46
            static let nearWhiteCoreBoostFactor: CGFloat = 0.17
            static let nearWhiteCoreAnchorWeight: CGFloat = 0.24
        }

        enum Decontamination {
            static let strongSaturation = 0.992
            static let adaptiveRiskBlurRadius = 0.55
            static let highlightPreserveMinimum: CGFloat = 0.78
            static let highlightPreserveBlurRadius = 0.55
            static let darkRiskExpandedBlurRadius = 0.9
            static let adaptiveRiskWeight: CGFloat = 0.3
            static let subjectCoreRadius = 1.25
            static let subjectCoreBlurRadius = 0.35
            static let outerRingNarrowRadius = 0.88
            static let outerRingBlurRadius = 0.11
            static let safeEdgeBandWeight: CGFloat = 0.34
            static let topShiftY: CGFloat = -1.9
            static let topInfluenceBlurRadius = 0.68
            static let topGrayBandReductionWeight: CGFloat = 0.38
            // R2.1 (Package-5): decontam/compose handoff stage-1 tuning
            static let bottomShiftY: CGFloat = 1.75
            static let bottomInfluenceBlurRadius = 0.52
            static let bottomGrayFloatSupportWeight: CGFloat = 0.22
            static let bottomZoneUpperRatio: CGFloat = 0.46
            static let nearWhiteProtectThreshold: CGFloat = 0.7
            static let nearWhiteProtectBlurRadius = 0.48
            static let nearWhiteProtectGuardWeight: CGFloat = 0.82
            static let edgeTailCleanupBlurRadius = 0.38
            static let edgeTailCleanupWeight: CGFloat = 0.22
        }

        enum BoundaryRecovery {
            static let innerMaskRadius = 0.95
            static let outerMaskRadius = 1.65
            static let hardBoundaryBlurRadius = 0.75
            static let darkHardBoundaryBlurRadius = 0.62
            static let softBoundaryBlurRadius = 1.1
            static let hardRecoverUnsharpRadius = 0.85
            static let hardRecoverUnsharpIntensity = 0.34
            static let darkDensityUnsharpRadius = 0.7
            static let darkDensityUnsharpIntensity = 0.24
            static let darkDensityBrightness = -0.006
            static let darkDensityContrast = 1.035
            static let darkRecoverWeight: CGFloat = 0.52
            static let softRecoverContrast = 1.025
            static let softRecoverWeight: CGFloat = 0.34
            static let softMaskBlurRadius = 0.8
        }

        enum Fidelity {
            static let washoutRiskNormalizeStart = 0.025
            static let washoutRiskNormalizeRange = 0.23
            static let subjectCoreRadius = 1.45
            static let subjectCoreBlurRadius = 0.75
            static let innerMaskRadius = 0.85
            static let outerMaskRadius = 1.45
            static let darkBoundaryBlurRadius = 0.72
            static let hardBoundaryBlurRadius = 0.58
            static let subjectToneCoreWeightBase: CGFloat = 0.12
            static let subjectToneCoreWeightRiskScale: CGFloat = 0.45
            static let subjectToneWashoutWeightBase: CGFloat = 0.1
            static let subjectToneWashoutWeightRiskScale: CGFloat = 0.42
            static let subjectToneBlurRadius = 0.72
            static let toneRecoveryBrightnessBase = -0.001
            static let toneRecoveryBrightnessRiskScale = -0.012
            static let toneRecoveryContrastBase = 1.015
            static let toneRecoveryContrastRiskScale = 0.055
            static let combinedCoreWeightBase: CGFloat = 0.14
            static let combinedCoreWeightRiskScale: CGFloat = 0.14
            static let combinedHardWeightBase: CGFloat = 0.24
            static let combinedHardWeightRiskScale: CGFloat = 0.18
            static let combinedDarkWeightBase: CGFloat = 0.48
            static let combinedDarkWeightRiskScale: CGFloat = 0.22
            static let combinedMaskBlurRadius = 0.65
            static let densityRecoveryBrightnessBase = -0.003
            static let densityRecoveryBrightnessRiskScale = -0.009
            static let densityRecoveryContrastBase = 1.02
            static let densityRecoveryContrastRiskScale = 0.06
            static let darkEdgeRecoveryUnsharpRadius = 0.72
            static let darkEdgeRecoveryUnsharpIntensity = 0.18
            static let darkEdgeRecoveryBrightness = -0.007
            static let darkEdgeRecoveryContrast = 1.04
            static let darkEdgeRecoveryMaskWeightBase: CGFloat = 0.46
            static let darkEdgeRecoveryMaskWeightRiskScale: CGFloat = 0.24
            static let washoutMaskBlurRadius = 0.75
        }

        enum Quality {
            static let coverageRiskLower = 0.015
            static let coverageRiskUpper = 0.93
            static let coverageReviewLower = 0.04
            static let coverageReviewUpper = 0.84

            static let riskForegroundWashout = 0.14
            static let riskDarkEdgeWashout = 0.13
            static let riskHardEdgeInstability = 0.12
            static let riskFringe = 0.18
            static let riskHighlightCut = 0.2
            static let riskThinEdge = 0.09
            static let riskSoftEdge = 0.075

            static let reviewEdgeComplexity = 0.14
            static let reviewEdgeRatio = 0.11
            static let reviewForegroundWashout = 0.09
            static let reviewDarkEdgeWashout = 0.08
            static let reviewHardEdgeInstability = 0.075
            static let reviewFringe = 0.12
            static let reviewThinEdge = 0.055

            static let hardCaseDarkEdgeWashout = 0.12
            static let hardCaseForegroundWashout = 0.11
            static let hardCaseHardEdgeInstability = 0.09
            static let hardCaseFringe = 0.16
            static let hardCaseHighlightCut = 0.19
            static let hardCaseThinEdge = 0.065
            static let hardCaseSoftEdge = 0.075
        }

        enum DynamicRadii {
            static func maskFeatherRadius(for extent: CGRect) -> Double {
                max(0.8, min(2.2, Double(min(extent.width, extent.height)) / 1200))
            }

            static func edgeBandRadius(for extent: CGRect) -> Double {
                max(1.2, min(3.5, Double(min(extent.width, extent.height)) / 640))
            }

            static func shadowBlurRadius(for extent: CGRect) -> Double {
                max(2.2, min(10.0, Double(min(extent.width, extent.height)) * 0.012))
            }

            static func shadowYOffset(for extent: CGRect) -> CGFloat {
                max(2, extent.height * 0.006)
            }

            static func shadowOpacity(for extent: CGRect) -> CGFloat {
                let normalized = max(0, min(1, extent.width / 1800))
                return 0.07 + normalized * 0.02
            }
        }
    }

    private struct SegmentationOutput {
        let maskImage: CIImage
        let metadata: [String: String]
    }

    private struct TinyORTSignalSummary {
        let coverageRatio: Double
        let confidenceScore: Double
        let edgeDensityScore: Double
    }

    private struct SegmentationProvider {
        let makeMask: (_ sourceImage: CIImage, _ extent: CGRect) throws -> SegmentationOutput
    }

    @available(iOS 17.0, *)
    private nonisolated static let visionSegmentationProvider = SegmentationProvider { sourceImage, extent in
        let request = VNGenerateForegroundInstanceMaskRequest()
        let requestHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        try requestHandler.perform([request])

        guard let observation = request.results?.first else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }

        let instances = observation.allInstances
        guard !instances.isEmpty else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }

        let maskPixelBuffer = try observation.generateScaledMaskForImage(
            forInstances: instances,
            from: requestHandler
        )
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer).cropped(to: extent)
        return SegmentationOutput(
            maskImage: maskImage,
            metadata: [
                "segmentation_provider": "vision",
                "segmentation_request": "VNGenerateForegroundInstanceMaskRequest",
                "segmentation_revision_policy": "default_unpinned",
                "segmentation_revision_resolved": "\(request.revision)",
                "segmentation_instance_count": "\(instances.count)",
                "segmentation_track": "stable_vision_default"
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static let visionAttentionSaliencyProvider = SegmentationProvider { sourceImage, extent in
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let requestHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        try requestHandler.perform([request])

        guard let observation = request.results?.first else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }

        let rawMask = CIImage(cvPixelBuffer: observation.pixelBuffer)
        let scaledMask = normalizedMask(rawMask, targetExtent: extent)
        return SegmentationOutput(
            maskImage: scaledMask,
            metadata: [
                "segmentation_provider": SegmentationProviderID.visionAttentionSaliency.rawValue,
                "segmentation_request": "VNGenerateAttentionBasedSaliencyImageRequest",
                "segmentation_revision_policy": "default_unpinned",
                "segmentation_revision_resolved": "\(request.revision)",
                "segmentation_instance_count": "1",
                "segmentation_track": "admission_candidate_attention_saliency_v1"
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static let visionObjectnessSaliencyProvider = SegmentationProvider { sourceImage, extent in
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        let requestHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        try requestHandler.perform([request])

        guard let observation = request.results?.first else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }

        let rawMask = CIImage(cvPixelBuffer: observation.pixelBuffer)
        let scaledMask = normalizedMask(rawMask, targetExtent: extent)
        return SegmentationOutput(
            maskImage: scaledMask,
            metadata: [
                "segmentation_provider": SegmentationProviderID.visionObjectnessSaliency.rawValue,
                "segmentation_request": "VNGenerateObjectnessBasedSaliencyImageRequest",
                "segmentation_revision_policy": "default_unpinned",
                "segmentation_revision_resolved": "\(request.revision)",
                "segmentation_instance_count": "1",
                "segmentation_track": "admission_candidate_objectness_saliency_v1"
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static let visionForegroundLatestRevisionProvider = SegmentationProvider { sourceImage, extent in
        let request = VNGenerateForegroundInstanceMaskRequest()
        if let latestRevision = VNGenerateForegroundInstanceMaskRequest.supportedRevisions.last {
            request.revision = latestRevision
        }
        let requestHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        try requestHandler.perform([request])

        guard let observation = request.results?.first else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }

        let instances = observation.allInstances
        guard !instances.isEmpty else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }

        let maskPixelBuffer = try observation.generateScaledMaskForImage(
            forInstances: instances,
            from: requestHandler
        )
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer).cropped(to: extent)
        return SegmentationOutput(
            maskImage: maskImage,
            metadata: [
                "segmentation_provider": SegmentationProviderID.visionForegroundLatestRevision.rawValue,
                "segmentation_request": "VNGenerateForegroundInstanceMaskRequest",
                "segmentation_revision_policy": "pinned_latest_supported",
                "segmentation_revision_resolved": "\(request.revision)",
                "segmentation_instance_count": "\(instances.count)",
                "segmentation_track": "admission_candidate_foreground_latest_revision_v1"
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static let visionForegroundObjectnessHybridProvider = SegmentationProvider { sourceImage, extent in
        let foregroundRequest = VNGenerateForegroundInstanceMaskRequest()
        let foregroundHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        try foregroundHandler.perform([foregroundRequest])

        if let foregroundObservation = foregroundRequest.results?.first {
            let foregroundInstances = foregroundObservation.allInstances
            if !foregroundInstances.isEmpty {
                let foregroundMaskBuffer = try foregroundObservation.generateScaledMaskForImage(
                    forInstances: foregroundInstances,
                    from: foregroundHandler
                )
                let foregroundMaskImage = CIImage(cvPixelBuffer: foregroundMaskBuffer).cropped(to: extent)
                return SegmentationOutput(
                    maskImage: foregroundMaskImage,
                    metadata: [
                        "segmentation_provider": SegmentationProviderID.visionForegroundObjectnessHybrid.rawValue,
                        "segmentation_request": "VNGenerateForegroundInstanceMaskRequest+VNGenerateObjectnessBasedSaliencyImageRequest",
                        "segmentation_revision_policy": "foreground_default_with_objectness_fallback",
                        "segmentation_revision_resolved": "\(foregroundRequest.revision)",
                        "segmentation_instance_count": "\(foregroundInstances.count)",
                        "segmentation_track": "admission_candidate_foreground_objectness_hybrid_v1",
                        "segmentation_fallback_path": "foreground_instance_mask"
                    ]
                )
            }
        }

        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        let objectnessHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        try objectnessHandler.perform([objectnessRequest])
        guard let objectnessObservation = objectnessRequest.results?.first else {
            throw CaptureWhiteBackgroundProcessorError.subjectMaskUnavailable
        }
        let objectnessRawMask = CIImage(cvPixelBuffer: objectnessObservation.pixelBuffer)
        let objectnessScaledMask = normalizedMask(objectnessRawMask, targetExtent: extent)
        return SegmentationOutput(
            maskImage: objectnessScaledMask,
            metadata: [
                "segmentation_provider": SegmentationProviderID.visionForegroundObjectnessHybrid.rawValue,
                "segmentation_request": "VNGenerateForegroundInstanceMaskRequest+VNGenerateObjectnessBasedSaliencyImageRequest",
                "segmentation_revision_policy": "foreground_default_with_objectness_fallback",
                "segmentation_revision_resolved": "\(foregroundRequest.revision)",
                "segmentation_instance_count": "1",
                "segmentation_track": "admission_candidate_foreground_objectness_hybrid_v1",
                "segmentation_fallback_path": "objectness_saliency_fallback"
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static let biRefNetProvider = SegmentationProvider { sourceImage, extent in
        let model = try loadBiRefNetCoreMLModel()
        let inferenceOutput = try runBiRefNetCoreMLInference(
            sourceImage: sourceImage,
            extent: extent,
            model: model
        )
        return SegmentationOutput(
            maskImage: inferenceOutput.maskImage,
            metadata: [
                "segmentation_provider": SegmentationProviderID.birefnet.rawValue,
                "segmentation_revision_policy": "runtime_coreml_model_loading",
                "segmentation_revision_resolved": "n/a",
                "segmentation_instance_count": "1",
                "segmentation_track": BiRefNetConfig.track,
                "segmentation_model_resource": currentBiRefNetResourceName(),
                "segmentation_model_output_feature": BiRefNetConfig.preferredOutputFeatureName
            ].merging(inferenceOutput.metadata) { _, new in new }
        )
    }

    @available(iOS 17.0, *)
    private struct BiRefNetCoreMLInferenceOutput {
        let maskImage: CIImage
        let metadata: [String: String]
    }

    @available(iOS 17.0, *)
    private nonisolated static func runBiRefNetCoreMLInference(
        sourceImage: CIImage,
        extent: CGRect,
        model: MLModel
    ) throws -> BiRefNetCoreMLInferenceOutput {
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        if let multiArrayInput = inputDescriptions["input"], multiArrayInput.type == .multiArray {
            return try runBiRefNetMultiArrayInference(
                sourceImage: sourceImage,
                extent: extent,
                model: model,
                inputFeatureName: "input",
                inputFeatureDescription: multiArrayInput
            )
        }
        if let firstMultiArrayInput = inputDescriptions.first(where: { $0.value.type == .multiArray }) {
            return try runBiRefNetMultiArrayInference(
                sourceImage: sourceImage,
                extent: extent,
                model: model,
                inputFeatureName: firstMultiArrayInput.key,
                inputFeatureDescription: firstMultiArrayInput.value
            )
        }
        if inputDescriptions.contains(where: { $0.value.type == .image }) {
            return try runBiRefNetVisionImageInference(
                sourceImage: sourceImage,
                extent: extent,
                model: model
            )
        }
        throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
    }

    @available(iOS 17.0, *)
    private nonisolated static func runBiRefNetVisionImageInference(
        sourceImage: CIImage,
        extent: CGRect,
        model: MLModel
    ) throws -> BiRefNetCoreMLInferenceOutput {
        let visionModel = try VNCoreMLModel(for: model)
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill
        let requestHandler = VNImageRequestHandler(ciImage: sourceImage, options: [:])
        do {
            try requestHandler.perform([request])
        } catch {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        guard let observations = request.results, !observations.isEmpty else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        if let pixelBufferObservation = observations.first(where: { $0 is VNPixelBufferObservation }) as? VNPixelBufferObservation {
            let rawMask = CIImage(cvPixelBuffer: pixelBufferObservation.pixelBuffer)
            return BiRefNetCoreMLInferenceOutput(
                maskImage: normalizedMask(rawMask, targetExtent: extent),
                metadata: [
                    "segmentation_request": "VNCoreMLRequest(BiRefNet)",
                    "segmentation_model_input_type": "image",
                    "segmentation_model_output_type": "pixelBuffer"
                ]
            )
        }
        if let featureValueObservation = observations
            .compactMap({ $0 as? VNCoreMLFeatureValueObservation })
            .first(where: { $0.featureName == BiRefNetConfig.preferredOutputFeatureName && $0.featureValue.multiArrayValue != nil })
            ?? observations
                .compactMap({ $0 as? VNCoreMLFeatureValueObservation })
                .first(where: { $0.featureValue.multiArrayValue != nil }) {
            guard let multiArray = featureValueObservation.featureValue.multiArrayValue else {
                throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
            }
            let rawMask = try maskCIImage(from: multiArray)
            return BiRefNetCoreMLInferenceOutput(
                maskImage: normalizedMask(rawMask, targetExtent: extent),
                metadata: [
                    "segmentation_request": "VNCoreMLRequest(BiRefNet)",
                    "segmentation_model_input_type": "image",
                    "segmentation_model_output_type": "multiArray",
                    "segmentation_model_output_feature": featureValueObservation.featureName
                ]
            )
        }
        throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
    }

    @available(iOS 17.0, *)
    private nonisolated static func runBiRefNetMultiArrayInference(
        sourceImage: CIImage,
        extent: CGRect,
        model: MLModel,
        inputFeatureName: String,
        inputFeatureDescription: MLFeatureDescription
    ) throws -> BiRefNetCoreMLInferenceOutput {
        let modelInput = try makeBiRefNetCoreMLInputMultiArray(
            sourceImage: sourceImage,
            inputFeatureDescription: inputFeatureDescription
        )
        let inputProvider = try MLDictionaryFeatureProvider(dictionary: [
            inputFeatureName: MLFeatureValue(multiArray: modelInput.array)
        ])

        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: inputProvider)
        } catch {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        let preferredOutput = prediction.featureValue(for: BiRefNetConfig.preferredOutputFeatureName)?.multiArrayValue
        let outputFeatureName: String
        let outputMultiArray: MLMultiArray
        if let preferredOutput {
            outputFeatureName = BiRefNetConfig.preferredOutputFeatureName
            outputMultiArray = preferredOutput
        } else if let fallback = prediction.featureNames
            .sorted()
            .compactMap({ name -> (String, MLMultiArray)? in
                guard let multiArray = prediction.featureValue(for: name)?.multiArrayValue else {
                    return nil
                }
                return (name, multiArray)
            })
            .first {
            outputFeatureName = fallback.0
            outputMultiArray = fallback.1
        } else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        let rawMask = try maskCIImage(from: outputMultiArray)
        return BiRefNetCoreMLInferenceOutput(
            maskImage: normalizedMask(rawMask, targetExtent: extent),
            metadata: [
                "segmentation_request": "MLModel.prediction(BiRefNetCoreML)",
                "segmentation_model_input_type": "multiArray",
                "segmentation_model_input_feature": inputFeatureName,
                "segmentation_model_input_shape": modelInput.shapeDescription,
                "segmentation_model_input_data_type": modelInput.dataTypeDescription,
                "segmentation_model_output_type": "multiArray",
                "segmentation_model_output_feature": outputFeatureName
            ]
        )
    }

    @available(iOS 17.0, *)
    private struct BiRefNetCoreMLInputMultiArray {
        let array: MLMultiArray
        let shapeDescription: String
        let dataTypeDescription: String
    }

    @available(iOS 17.0, *)
    private nonisolated static func makeBiRefNetCoreMLInputMultiArray(
        sourceImage: CIImage,
        inputFeatureDescription: MLFeatureDescription
    ) throws -> BiRefNetCoreMLInputMultiArray {
        guard let multiArrayConstraint = inputFeatureDescription.multiArrayConstraint else {
            throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
        }

        let shape = multiArrayConstraint.shape.map { Int(truncating: $0) }
        guard shape.count >= 3 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
        }
        let channelIndex = shape.count - 3
        let heightIndex = shape.count - 2
        let widthIndex = shape.count - 1
        let channels = shape[channelIndex]
        let targetHeight = shape[heightIndex]
        let targetWidth = shape[widthIndex]
        guard channels == 3, targetWidth > 0, targetHeight > 0 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
        }

        let supportedDataType = multiArrayConstraint.dataType
        guard supportedDataType == .float16 || supportedDataType == .float32 || supportedDataType == .double else {
            throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
        }

        let inputArray = try MLMultiArray(
            shape: shape.map { NSNumber(value: $0) },
            dataType: supportedDataType
        )
        let strides = inputArray.strides.map { Int(truncating: $0) }
        guard strides.count == shape.count else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        let sourceExtent = sourceImage.extent
        guard sourceExtent.width > 0, sourceExtent.height > 0 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        let scaleX = CGFloat(targetWidth) / sourceExtent.width
        let scaleY = CGFloat(targetHeight) / sourceExtent.height
        let resized = sourceImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        let renderContext = CIContext(options: nil)
        var rgbaBytes = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
        renderContext.render(
            resized,
            toBitmap: &rgbaBytes,
            rowBytes: targetWidth * 4,
            bounds: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let means: [Double] = [0.485, 0.456, 0.406]
        let stds: [Double] = [0.229, 0.224, 0.225]
        let strideC = strides[channelIndex]
        let strideH = strides[heightIndex]
        let strideW = strides[widthIndex]
        let arrayCount = inputArray.count

        func linearIndex(channel: Int, y: Int, x: Int) -> Int {
            channel * strideC + y * strideH + x * strideW
        }

        switch supportedDataType {
        case .float16:
            let pointer = inputArray.dataPointer.assumingMemoryBound(to: UInt16.self)
            for y in 0..<targetHeight {
                for x in 0..<targetWidth {
                    let rgbaIndex = ((y * targetWidth) + x) * 4
                    for channel in 0..<3 {
                        let pixel = Double(rgbaBytes[rgbaIndex + channel]) / 255.0
                        let normalized = (pixel - means[channel]) / stds[channel]
                        let index = linearIndex(channel: channel, y: y, x: x)
                        guard index >= 0, index < arrayCount else {
                            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
                        }
                        pointer[index] = Float16(normalized).bitPattern
                    }
                }
            }
        case .float32:
            let pointer = inputArray.dataPointer.assumingMemoryBound(to: Float.self)
            for y in 0..<targetHeight {
                for x in 0..<targetWidth {
                    let rgbaIndex = ((y * targetWidth) + x) * 4
                    for channel in 0..<3 {
                        let pixel = Double(rgbaBytes[rgbaIndex + channel]) / 255.0
                        let normalized = (pixel - means[channel]) / stds[channel]
                        let index = linearIndex(channel: channel, y: y, x: x)
                        guard index >= 0, index < arrayCount else {
                            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
                        }
                        pointer[index] = Float(normalized)
                    }
                }
            }
        case .double:
            let pointer = inputArray.dataPointer.assumingMemoryBound(to: Double.self)
            for y in 0..<targetHeight {
                for x in 0..<targetWidth {
                    let rgbaIndex = ((y * targetWidth) + x) * 4
                    for channel in 0..<3 {
                        let pixel = Double(rgbaBytes[rgbaIndex + channel]) / 255.0
                        let normalized = (pixel - means[channel]) / stds[channel]
                        let index = linearIndex(channel: channel, y: y, x: x)
                        guard index >= 0, index < arrayCount else {
                            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
                        }
                        pointer[index] = normalized
                    }
                }
            }
        default:
            throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
        }

        return BiRefNetCoreMLInputMultiArray(
            array: inputArray,
            shapeDescription: shape.map(String.init).joined(separator: "x"),
            dataTypeDescription: String(describing: supportedDataType)
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static let biRefNetTinyORTProvider = SegmentationProvider { sourceImage, extent in
        let modelURL = try loadBiRefNetTinyORTModelURL()
        let inferenceOutput = try runBiRefNetTinyORTInference(
            sourceImage: sourceImage,
            extent: extent,
            modelURL: modelURL
        )
        var metadata: [String: String] = [
            "segmentation_provider": SegmentationProviderID.birefnetTinyORT.rawValue,
            "segmentation_request": "ORTSession(BiRefNetTinyONNX)",
            "segmentation_revision_policy": "runtime_tiny_onnx_ort_loading",
            "segmentation_revision_resolved": "n/a",
            "segmentation_instance_count": "1",
            "segmentation_track": BiRefNetConfig.tinyORTTrack,
            "segmentation_model_path": modelURL.path
        ]
        metadata.merge(inferenceOutput.signalMetadata) { _, new in new }
        return SegmentationOutput(
            maskImage: inferenceOutput.maskImage,
            metadata: metadata
        )
    }

    nonisolated static func process(confirmedStillPhoto: CaptureStillPhotoResult) async throws -> CaptureProcessedPhotoResult {
        try await Task.detached(priority: .userInitiated) {
            try processSync(confirmedStillPhoto: confirmedStillPhoto)
        }.value
    }

    private nonisolated static func processSync(
        confirmedStillPhoto: CaptureStillPhotoResult
    ) throws -> CaptureProcessedPhotoResult {
        guard #available(iOS 17.0, *) else {
            throw CaptureWhiteBackgroundProcessorError.unsupportedSystemVersion
        }
        let segmentationProvider = resolveSegmentationProvider(from: confirmedStillPhoto.metadata)
        return try processOnSupportedSystem(
            confirmedStillPhoto: confirmedStillPhoto,
            segmentationProvider: segmentationProvider
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func processOnSupportedSystem(
        confirmedStillPhoto: CaptureStillPhotoResult,
        segmentationProvider: SegmentationProvider = visionSegmentationProvider
    ) throws -> CaptureProcessedPhotoResult {
        guard let inputImage = CIImage(data: confirmedStillPhoto.imageData) else {
            throw CaptureWhiteBackgroundProcessorError.invalidInputImage
        }
        let extent = inputImage.extent.integral

        let segmentationOutput = try segmentationProvider.makeMask(
            inputImage,
            extent
        )
        let segmentationProviderID = segmentationOutput.metadata["segmentation_provider"]
        let renderContext = makeRenderContext(for: segmentationProviderID)
        let subjectMask = segmentationOutput.maskImage
        let refinementArtifacts = refineSubjectMask(subjectMask, sourceImage: inputImage, extent: extent)
        let refinedMaskImage = refinementArtifacts.refinedMask

        let decontaminatedSubjectImage = runEdgeDecontaminationStage(
            sourceImage: inputImage,
            refinedMask: refinedMaskImage,
            edgeBandMask: refinementArtifacts.edgeBandMask,
            chromaSpillRiskMask: refinementArtifacts.chromaSpillRiskMask,
            darkEdgeRiskMask: refinementArtifacts.darkEdgeRiskMask,
            extent: extent
        )
        let compositedImage = try composeOnWhiteBackgroundStage(
            subjectImage: decontaminatedSubjectImage,
            refinedMask: refinedMaskImage,
            extent: extent
        )
        let outputImage = runBoundaryContrastRecoveryStage(
            compositedImage: compositedImage,
            sourceImage: inputImage,
            refinedMask: refinedMaskImage,
            hardEdgeMask: refinementArtifacts.hardEdgeMask,
            darkEdgeRiskMask: refinementArtifacts.darkEdgeRiskMask,
            extent: extent
        )
        let fidelityPreservedImage = runForegroundFidelityStage(
            compositedImage: outputImage,
            sourceImage: inputImage,
            refinedMask: refinedMaskImage,
            hardEdgeMask: refinementArtifacts.hardEdgeMask,
            darkEdgeRiskMask: refinementArtifacts.darkEdgeRiskMask,
            extent: extent,
            renderContext: renderContext
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let outputData = renderContext.jpegRepresentation(of: fidelityPreservedImage, colorSpace: colorSpace) else {
            throw CaptureWhiteBackgroundProcessorError.outputEncodingFailed
        }
        let qualityMetadataUsesFallback = shouldUseTinyORTCoverageMetadataFallback(segmentationProviderID: segmentationProviderID)
        var qualityMetadata: [String: String]
        if qualityMetadataUsesFallback {
            // R18 signal recovery:
            // keep simulator runtime stability guard, but replace one-size-fits-all review
            // metadata with lightweight logits-driven signal summary from ORT inference.
            qualityMetadata = makeTinyORTRuntimeSignalMetadata(segmentationMetadata: segmentationOutput.metadata)
            qualityMetadata["quality_metadata_mode"] = "tiny_ort_runtime_signal_v1"
        } else {
            qualityMetadata = buildQualityMetadata(
                refinedMask: refinedMaskImage,
                edgeBandMask: refinementArtifacts.edgeBandMask,
                edgeGuideMask: refinementArtifacts.edgeGuideMask,
                highlightEdgeMask: refinementArtifacts.highlightEdgeMask,
                hardEdgeMask: refinementArtifacts.hardEdgeMask,
                darkEdgeRiskMask: refinementArtifacts.darkEdgeRiskMask,
                thinStructureMask: refinementArtifacts.thinStructureMask,
                chromaSpillRiskMask: refinementArtifacts.chromaSpillRiskMask,
                outputImage: fidelityPreservedImage,
                sourceImage: inputImage,
                extent: extent,
                renderContext: renderContext
            )
        }
        qualityMetadata["segmentation_boundary"] = "SegmentationProvider"
        for (key, value) in segmentationOutput.metadata {
            qualityMetadata[key] = value
        }

        return CaptureProcessedPhotoResult(
            sourceStillPhotoID: confirmedStillPhoto.id,
            imageData: outputData,
            pixelSize: CGSize(width: fidelityPreservedImage.extent.width, height: fidelityPreservedImage.extent.height),
            metadata: qualityMetadata
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func resolveSegmentationProvider(
        from stillMetadata: [String: String]
    ) -> SegmentationProvider {
        let metadataHint = stillMetadata["baseline_segmentation_provider"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let environmentHint = ProcessInfo.processInfo.environment[SegmentationExperimentEnvironment.providerKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = (metadataHint?.isEmpty == false ? metadataHint : environmentHint) ?? SegmentationProviderID.vision.rawValue
        let normalized = rawValue.lowercased()

        switch normalized {
        case SegmentationProviderID.visionAttentionSaliency.rawValue,
             "vision-saliency-attention",
             "attention_saliency",
             "candidate_attention":
            return visionAttentionSaliencyProvider
        case SegmentationProviderID.visionObjectnessSaliency.rawValue,
             "vision-saliency-objectness",
             "objectness_saliency",
             "candidate_objectness":
            return visionObjectnessSaliencyProvider
        case SegmentationProviderID.visionForegroundLatestRevision.rawValue,
             "vision-foreground-latest",
             "foreground_latest_revision",
             "candidate_foreground_latest":
            return visionForegroundLatestRevisionProvider
        case SegmentationProviderID.visionForegroundObjectnessHybrid.rawValue,
             "vision-foreground-objectness-hybrid",
             "foreground_objectness_hybrid",
             "candidate_foreground_objectness_hybrid":
            return visionForegroundObjectnessHybridProvider
        case SegmentationProviderID.birefnet.rawValue,
             "candidate_birefnet",
             "vision-birefnet":
            return biRefNetProvider
        case SegmentationProviderID.birefnetTinyORT.rawValue,
             "candidate_birefnet_tiny_ort",
             "candidate_birefnet_tiny":
            return biRefNetTinyORTProvider
        default:
            return visionSegmentationProvider
        }
    }

    @available(iOS 17.0, *)
    private nonisolated static func loadBiRefNetCoreMLModel() throws -> MLModel {
        if let explicitModelPath = ProcessInfo.processInfo.environment[SegmentationExperimentEnvironment.birefnetModelPathKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitModelPath.isEmpty {
            let explicitURL = URL(fileURLWithPath: explicitModelPath).resolvingSymlinksInPath()
            guard FileManager.default.fileExists(atPath: explicitURL.path) else {
                throw CaptureWhiteBackgroundProcessorError.segmentationModelUnavailable
            }
            let loadableURL = try loadableCoreMLURL(from: explicitURL)
            return try MLModel(contentsOf: loadableURL)
        }

        let bundle = Bundle.main
        let resourceCandidates = [currentBiRefNetResourceName()] + BiRefNetConfig.fallbackResourceNames
        for resourceName in resourceCandidates {
            if let modelURL = bundle.url(forResource: resourceName, withExtension: "mlmodelc") {
                return try MLModel(contentsOf: modelURL)
            }
            if let modelPackageURL = bundle.url(forResource: resourceName, withExtension: "mlpackage") {
                let loadableURL = try loadableCoreMLURL(from: modelPackageURL)
                return try MLModel(contentsOf: loadableURL)
            }
            if let nestedModelURL = findBiRefNetModelInBundle(named: resourceName, bundle: bundle, extensions: ["mlmodelc", "mlpackage"]) {
                let loadableURL = try loadableCoreMLURL(from: nestedModelURL)
                return try MLModel(contentsOf: loadableURL)
            }
        }
        throw CaptureWhiteBackgroundProcessorError.segmentationModelUnavailable
    }

    private nonisolated static func findBiRefNetModelInBundle(
        named resourceName: String,
        bundle: Bundle,
        extensions: [String]
    ) -> URL? {
        guard let resourceRoot = bundle.resourceURL else {
            return nil
        }
        let modelFolderNames = Set(extensions.map { "\(resourceName).\($0)" })
        let enumerator = FileManager.default.enumerator(
            at: resourceRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        while let next = enumerator?.nextObject() as? URL {
            if modelFolderNames.contains(next.lastPathComponent) {
                return next
            }
        }
        return nil
    }

    private nonisolated static func loadableCoreMLURL(from modelURL: URL) throws -> URL {
        let resolvedURL = modelURL.resolvingSymlinksInPath()
        let pathExtension = resolvedURL.pathExtension.lowercased()
        if pathExtension == "mlmodelc" {
            return resolvedURL
        }
        if pathExtension == "mlpackage" || pathExtension == "mlmodel" {
            return try MLModel.compileModel(at: resolvedURL)
        }
        throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
    }

    private nonisolated static func currentBiRefNetResourceName() -> String {
        let rawValue = ProcessInfo.processInfo.environment[SegmentationExperimentEnvironment.birefnetResourceKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawValue, !rawValue.isEmpty {
            return rawValue
        }
        return BiRefNetConfig.defaultResourceName
    }

    private nonisolated static func loadBiRefNetTinyORTModelURL() throws -> URL {
        if let explicitPath = ProcessInfo.processInfo.environment[SegmentationExperimentEnvironment.birefnetTinyORTModelPathKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            let explicitURL = URL(fileURLWithPath: explicitPath).resolvingSymlinksInPath()
            guard FileManager.default.fileExists(atPath: explicitURL.path) else {
                throw CaptureWhiteBackgroundProcessorError.segmentationModelUnavailable
            }
            guard explicitURL.pathExtension.lowercased() == "onnx" else {
                throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
            }
            return explicitURL
        }

        if let bundledModelURL = findTinyORTModelInBundle(named: BiRefNetConfig.tinyORTBundledModelFileName) {
            return bundledModelURL
        }

        let defaultURL = URL(fileURLWithPath: BiRefNetConfig.tinyORTDefaultModelPath).resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: defaultURL.path) else {
            throw CaptureWhiteBackgroundProcessorError.segmentationModelUnavailable
        }
        guard defaultURL.pathExtension.lowercased() == "onnx" else {
            throw CaptureWhiteBackgroundProcessorError.segmentationModelContractMismatch
        }
        return defaultURL
    }

    private nonisolated static func findTinyORTModelInBundle(named fileName: String) -> URL? {
        guard let resourceRoot = Bundle.main.resourceURL else {
            return nil
        }
        let enumerator = FileManager.default.enumerator(
            at: resourceRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        while let next = enumerator?.nextObject() as? URL {
            if next.lastPathComponent == fileName, next.pathExtension.lowercased() == "onnx" {
                return next
            }
        }
        return nil
    }

    private nonisolated static func makeRenderContext(for segmentationProviderID: String?) -> CIContext {
#if targetEnvironment(simulator)
        if segmentationProviderID == SegmentationProviderID.birefnetTinyORT.rawValue {
            // Tiny ORT admission autorun on simulator repeatedly hit CI::MetalContext crashes.
            // Force software rendering on this path to keep runtime coverage stable.
            return CIContext(options: [.useSoftwareRenderer: true])
        }
#endif
        return CIContext()
    }

    private nonisolated static func shouldUseTinyORTCoverageMetadataFallback(segmentationProviderID: String?) -> Bool {
#if targetEnvironment(simulator)
        return segmentationProviderID == SegmentationProviderID.birefnetTinyORT.rawValue
#else
        return false
#endif
    }

    @available(iOS 17.0, *)
    private struct TinyORTInferenceOutput {
        let maskImage: CIImage
        let signalMetadata: [String: String]
    }

    @available(iOS 17.0, *)
    private nonisolated static func runBiRefNetTinyORTInference(
        sourceImage: CIImage,
        extent: CGRect,
        modelURL: URL
    ) throws -> TinyORTInferenceOutput {
        let runtimeDependencyUnavailableCode = 1001
        let inputTensorData = try makeBiRefNetTinyORTInputTensorData(
            sourceImage: sourceImage,
            targetWidth: BiRefNetConfig.tinyORTInputWidth,
            targetHeight: BiRefNetConfig.tinyORTInputHeight
        )

        var outputWidth = 0
        var outputHeight = 0
        let logitsData: Data
        do {
            logitsData = try BiRefNetTinyORTBridge.runTinyModel(
                atPath: modelURL.path,
                inputTensorData: inputTensorData,
                inputWidth: BiRefNetConfig.tinyORTInputWidth,
                inputHeight: BiRefNetConfig.tinyORTInputHeight,
                preferredOutputName: BiRefNetConfig.preferredOutputFeatureName,
                outputWidth: &outputWidth,
                outputHeight: &outputHeight
            )
        } catch let bridgeError as NSError {
            if bridgeError.domain == BiRefNetTinyORTBridgeErrorDomain,
               bridgeError.code == runtimeDependencyUnavailableCode {
                throw CaptureWhiteBackgroundProcessorError.segmentationRuntimeDependencyUnavailable
            }
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        let resolvedWidth = outputWidth > 0 ? outputWidth : BiRefNetConfig.tinyORTInputWidth
        let resolvedHeight = outputHeight > 0 ? outputHeight : BiRefNetConfig.tinyORTInputHeight
        let rawMask = try maskCIImage(
            fromLogitsData: logitsData,
            width: resolvedWidth,
            height: resolvedHeight
        )
        let signalSummary = summarizeTinyORTSignals(
            logitsData: logitsData,
            width: resolvedWidth,
            height: resolvedHeight
        )
        let signalMetadata: [String: String] = [
            "tiny_ort_signal_coverage_ratio": String(format: "%.4f", signalSummary.coverageRatio),
            "tiny_ort_signal_confidence_score": String(format: "%.4f", signalSummary.confidenceScore),
            "tiny_ort_signal_edge_density_score": String(format: "%.4f", signalSummary.edgeDensityScore)
        ]
        return TinyORTInferenceOutput(
            maskImage: normalizedMask(rawMask, targetExtent: extent),
            signalMetadata: signalMetadata
        )
    }

    private nonisolated static func makeBiRefNetTinyORTInputTensorData(
        sourceImage: CIImage,
        targetWidth: Int,
        targetHeight: Int
    ) throws -> Data {
        let sourceExtent = sourceImage.extent
        guard sourceExtent.width > 0, sourceExtent.height > 0 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        let scaleX = CGFloat(targetWidth) / sourceExtent.width
        let scaleY = CGFloat(targetHeight) / sourceExtent.height
        let resized = sourceImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        let renderContext = CIContext(options: nil)
        var rgbaBytes = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
        renderContext.render(
            resized,
            toBitmap: &rgbaBytes,
            rowBytes: targetWidth * 4,
            bounds: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let means: [Float] = [0.485, 0.456, 0.406]
        let stds: [Float] = [0.229, 0.224, 0.225]
        let planeSize = targetWidth * targetHeight
        var tensorData = Data(count: planeSize * 3 * MemoryLayout<Float>.size)
        tensorData.withUnsafeMutableBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            for y in 0..<targetHeight {
                for x in 0..<targetWidth {
                    let rgbaIndex = ((y * targetWidth) + x) * 4
                    for channel in 0..<3 {
                        let pixelValue = Float(rgbaBytes[rgbaIndex + channel]) / 255.0
                        let normalized = (pixelValue - means[channel]) / stds[channel]
                        let tensorIndex = channel * planeSize + y * targetWidth + x
                        floatBuffer[tensorIndex] = normalized
                    }
                }
            }
        }
        return tensorData
    }

    private nonisolated static func maskCIImage(
        fromLogitsData logitsData: Data,
        width: Int,
        height: Int
    ) throws -> CIImage {
        guard width > 0, height > 0 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        let requiredBytes = width * height * MemoryLayout<Float>.size
        guard logitsData.count >= requiredBytes else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        var maskBytes = [UInt8](repeating: 0, count: width * height)
        logitsData.withUnsafeBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            for index in 0..<(width * height) {
                let raw = Double(floatBuffer[index])
                let activated = 1.0 / (1.0 + exp(-raw))
                let clamped = max(0.0, min(1.0, activated))
                maskBytes[index] = UInt8(clamped * 255.0)
            }
        }

        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let createStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard createStatus == kCVReturnSuccess, let pixelBuffer else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for row in 0..<height {
            let destination = baseAddress.advanced(by: row * destinationBytesPerRow)
            maskBytes.withUnsafeBytes { rawBuffer in
                let source = rawBuffer.baseAddress!.advanced(by: row * width)
                memcpy(destination, source, width)
            }
            if destinationBytesPerRow > width {
                memset(destination.advanced(by: width), 0, destinationBytesPerRow - width)
            }
        }

        return CIImage(cvPixelBuffer: pixelBuffer)
    }

    private nonisolated static func maskCIImage(from multiArray: MLMultiArray) throws -> CIImage {
        let dimensions = multiArray.shape.map { Int(truncating: $0) }
        let strides = multiArray.strides.map { Int(truncating: $0) }
        guard dimensions.count >= 2 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        let heightIndex = dimensions.count - 2
        let widthIndex = dimensions.count - 1
        let height = dimensions[heightIndex]
        let width = dimensions[widthIndex]
        guard height > 0, width > 0 else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        let scalarValue: (Int) -> Double = { linearIndex in
            multiArray[linearIndex].doubleValue
        }

        var maskBytes = [UInt8](repeating: 0, count: width * height)
        let strideHeight = strides[heightIndex]
        let strideWidth = strides[widthIndex]
        for y in 0..<height {
            for x in 0..<width {
                let linearIndex = y * strideHeight + x * strideWidth
                let raw = scalarValue(linearIndex)
                let activated = 1.0 / (1.0 + exp(-raw))
                let clamped = max(0.0, min(1.0, activated))
                maskBytes[(y * width) + x] = UInt8(clamped * 255.0)
            }
        }

        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let createStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard createStatus == kCVReturnSuccess, let pixelBuffer else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CaptureWhiteBackgroundProcessorError.segmentationInferenceFailed
        }
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        for row in 0..<height {
            let destination = baseAddress.advanced(by: row * destinationBytesPerRow)
            maskBytes.withUnsafeBytes { rawBuffer in
                let source = rawBuffer.baseAddress!.advanced(by: row * width)
                memcpy(destination, source, width)
            }
            if destinationBytesPerRow > width {
                memset(destination.advanced(by: width), 0, destinationBytesPerRow - width)
            }
        }

        return CIImage(cvPixelBuffer: pixelBuffer)
    }

    @available(iOS 17.0, *)
    private nonisolated static func normalizedMask(
        _ rawMask: CIImage,
        targetExtent: CGRect
    ) -> CIImage {
        let maskExtent = rawMask.extent
        guard maskExtent.width > 0, maskExtent.height > 0 else {
            return rawMask.cropped(to: targetExtent)
        }

        let scaleX = targetExtent.width / maskExtent.width
        let scaleY = targetExtent.height / maskExtent.height
        let scaledMask = rawMask
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(
                translationX: targetExtent.minX - maskExtent.minX * scaleX,
                y: targetExtent.minY - maskExtent.minY * scaleY
            ))
            .cropped(to: targetExtent)

        return scaledMask
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: targetExtent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func runEdgeDecontaminationStage(
        sourceImage: CIImage,
        refinedMask: CIImage,
        edgeBandMask: CIImage,
        chromaSpillRiskMask: CIImage,
        darkEdgeRiskMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        applyEdgeDecontamination(
            sourceImage: sourceImage,
            refinedMask: refinedMask,
            edgeBandMask: edgeBandMask,
            chromaSpillRiskMask: chromaSpillRiskMask,
            darkEdgeRiskMask: darkEdgeRiskMask,
            extent: extent
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func composeOnWhiteBackgroundStage(
        subjectImage: CIImage,
        refinedMask: CIImage,
        extent: CGRect
    ) throws -> CIImage {
        let whiteBackground = CIImage(
            color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        ).cropped(to: extent)
        let backgroundWithShadow = applyContactShadow(
            on: whiteBackground,
            refinedMask: refinedMask,
            extent: extent
        )

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = subjectImage
        blendFilter.maskImage = refinedMask
        blendFilter.backgroundImage = backgroundWithShadow

        guard let compositedImage = blendFilter.outputImage else {
            throw CaptureWhiteBackgroundProcessorError.outputCompositionFailed
        }
        return compositedImage
    }

    @available(iOS 17.0, *)
    private nonisolated static func runBoundaryContrastRecoveryStage(
        compositedImage: CIImage,
        sourceImage: CIImage,
        refinedMask: CIImage,
        hardEdgeMask: CIImage,
        darkEdgeRiskMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        applyBoundaryContrastRecovery(
            compositedImage: compositedImage,
            sourceImage: sourceImage,
            refinedMask: refinedMask,
            hardEdgeMask: hardEdgeMask,
            darkEdgeRiskMask: darkEdgeRiskMask,
            extent: extent
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func runForegroundFidelityStage(
        compositedImage: CIImage,
        sourceImage: CIImage,
        refinedMask: CIImage,
        hardEdgeMask: CIImage,
        darkEdgeRiskMask: CIImage,
        extent: CGRect,
        renderContext: CIContext
    ) -> CIImage {
        applyForegroundFidelityConservation(
            compositedImage: compositedImage,
            sourceImage: sourceImage,
            refinedMask: refinedMask,
            hardEdgeMask: hardEdgeMask,
            darkEdgeRiskMask: darkEdgeRiskMask,
            extent: extent,
            renderContext: renderContext
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func refineSubjectMask(
        _ maskImage: CIImage,
        sourceImage: CIImage,
        extent: CGRect
    ) -> MaskRefinementArtifacts {
        let closedMask = maskImage
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.closedMaskMorphologyRadius])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.closedMaskMorphologyRadius])

        let coreMask = closedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.coreMaskRadius])
            .cropped(to: extent)
        let expandedMask = closedMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.expandedMaskRadius])
            .cropped(to: extent)
        let edgeBandMask = expandedMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: coreMask])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)

        let edgeGuideMask = buildEdgeGuideMask(from: sourceImage, extent: extent)
        let highlightEdgeMask = buildHighlightRiskMask(
            from: sourceImage,
            edgeBandMask: edgeBandMask,
            extent: extent
        )
        let hardEdgeMask = buildHardEdgeCandidateMask(
            from: sourceImage,
            edgeBandMask: edgeBandMask,
            extent: extent
        )
        let darkEdgeRiskMask = buildDarkEdgeRiskMask(
            from: sourceImage,
            edgeBandMask: edgeBandMask,
            hardEdgeMask: hardEdgeMask,
            extent: extent
        )
        let thinStructureMask = buildThinStructureMask(
            from: edgeGuideMask,
            edgeBandMask: edgeBandMask,
            extent: extent
        )
        let contactEdgeSupportMask = buildContactEdgeSupportMask(
            from: coreMask,
            edgeBandMask: edgeBandMask,
            extent: extent
        )
        let nearWhiteCoreMask = buildNearWhiteCoreMask(
            from: sourceImage,
            coreMask: coreMask,
            extent: extent
        )
        let chromaSpillRiskMask = buildChromaSpillRiskMask(
            from: sourceImage,
            edgeBandMask: edgeBandMask,
            highlightMask: highlightEdgeMask,
            extent: extent
        )

        let featheredMask = coreMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: maskFeatherRadius(for: extent)])
            .cropped(to: extent)

        let edgeBandDetail = edgeGuideMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .cropped(to: extent)
        let scaledEdgeBandDetail = scaleMask(
            edgeBandDetail,
            factor: ProcessingConfig.Refinement.edgeBandDetailBoostFactor
        )
        let boostedMask = featheredMask
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: scaledEdgeBandDetail])
            .cropped(to: extent)

        let edgeRefinedBlend = CIFilter.blendWithMask()
        edgeRefinedBlend.inputImage = boostedMask
        edgeRefinedBlend.backgroundImage = featheredMask
        edgeRefinedBlend.maskImage = edgeBandMask
        let edgeRefinedMask = (edgeRefinedBlend.outputImage ?? featheredMask)
            .clampedToExtent()
            // R1.3: narrow transition width to avoid semi-transparent spill into subject body.
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.edgeTransitionBlurRadius])
            .cropped(to: extent)

        let reflectiveTransitionMask = highlightEdgeMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.reflectiveTransitionBlurRadius])
            .cropped(to: extent)
        let reflectiveProtectedBlend = CIFilter.blendWithMask()
        reflectiveProtectedBlend.inputImage = featheredMask
        reflectiveProtectedBlend.backgroundImage = edgeRefinedMask
        reflectiveProtectedBlend.maskImage = reflectiveTransitionMask
        let reflectiveProtectedMask = (reflectiveProtectedBlend.outputImage ?? edgeRefinedMask)
            .cropped(to: extent)

        let thinStructureBoost = scaleMask(
            thinStructureMask,
            factor: ProcessingConfig.Refinement.thinStructureBoostFactor
        )
        let thinStructureRestoredMask = reflectiveProtectedMask
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: thinStructureBoost])
            .cropped(to: extent)

        let hardEdgeContinuityMask = hardEdgeMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.hardEdgeContinuityBlurRadius])
            .cropped(to: extent)
        let hardEdgeStabilizedCandidate = thinStructureRestoredMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.hardEdgeStabilizedMaximumRadius])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.hardEdgeStabilizedMinimumRadius])
            .cropped(to: extent)
        let hardEdgeBlend = CIFilter.blendWithMask()
        hardEdgeBlend.inputImage = hardEdgeStabilizedCandidate
        hardEdgeBlend.backgroundImage = thinStructureRestoredMask
        hardEdgeBlend.maskImage = hardEdgeContinuityMask
        let hardEdgeStabilizedMask = (hardEdgeBlend.outputImage ?? thinStructureRestoredMask)
            .cropped(to: extent)

        let thinStructurePreserveBoost = scaleMask(
            thinStructureMask,
            factor: ProcessingConfig.Refinement.thinStructurePreserveBoostFactor
        )
        let contactEdgeSupportBoost = scaleMask(
            contactEdgeSupportMask,
            factor: ProcessingConfig.Refinement.contactEdgeSupportBoostFactor
        )
        let nearWhiteCoreBoost = scaleMask(
            nearWhiteCoreMask,
            factor: ProcessingConfig.Refinement.nearWhiteCoreBoostFactor
        )
        let preservationBoost = thinStructurePreserveBoost
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: contactEdgeSupportBoost])
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: nearWhiteCoreBoost])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let preservationAugmentedMask = hardEdgeStabilizedMask
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: preservationBoost])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let edgePreserveRegionMask = thinStructureMask
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: contactEdgeSupportMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.edgePreserveRegionBlurRadius])
            .cropped(to: extent)
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let smoothedAugmentedMask = preservationAugmentedMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.finalEdgeBlurRadius])
            .cropped(to: extent)
        let edgeAwareBlend = CIFilter.blendWithMask()
        edgeAwareBlend.inputImage = preservationAugmentedMask
        edgeAwareBlend.backgroundImage = smoothedAugmentedMask
        edgeAwareBlend.maskImage = edgePreserveRegionMask
        let edgeAwareRefinedMask = (edgeAwareBlend.outputImage ?? smoothedAugmentedMask)
            .cropped(to: extent)

        let finalRefinedMask = edgeAwareRefinedMask
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        // R1 regression fix: anchor subject core opacity to prevent whole-foreground washout.
        let subjectCoreAnchorMask = coreMask
            // R1.3: lift core alpha floor by widening core anchor coverage, while preserving soft edges.
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.coreAnchorMinimumRadius])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.coreAnchorMaximumRadius])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.coreAnchorBlurRadius])
            .cropped(to: extent)
        let fullOpacityMask = CIImage(color: .white).cropped(to: extent)
        let anchorBlend = CIFilter.blendWithMask()
        anchorBlend.inputImage = fullOpacityMask
        anchorBlend.backgroundImage = finalRefinedMask
        anchorBlend.maskImage = subjectCoreAnchorMask
        let anchoredRefinedMask = (anchorBlend.outputImage ?? finalRefinedMask)
            .cropped(to: extent)
        let nearWhiteCoreAnchorMask = weightMask(
            nearWhiteCoreMask,
            factor: ProcessingConfig.Refinement.nearWhiteCoreAnchorWeight
        )
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.nearWhiteCoreBlurRadius])
            .cropped(to: extent)
        let nearWhiteAnchorBlend = CIFilter.blendWithMask()
        nearWhiteAnchorBlend.inputImage = fullOpacityMask
        nearWhiteAnchorBlend.backgroundImage = anchoredRefinedMask
        nearWhiteAnchorBlend.maskImage = nearWhiteCoreAnchorMask
        let nearWhiteAnchoredMask = (nearWhiteAnchorBlend.outputImage ?? anchoredRefinedMask)
            .cropped(to: extent)

        // R1.4: raise alpha floor only in deep subject core.
        // Keep edge transition untouched by using a stronger-eroded interior mask.
        let deepCoreMask = coreMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.deepCoreMinimumRadius])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.deepCoreBlurRadius])
            .cropped(to: extent)
        let deepCoreAnchorBlend = CIFilter.blendWithMask()
        deepCoreAnchorBlend.inputImage = fullOpacityMask
        deepCoreAnchorBlend.backgroundImage = nearWhiteAnchoredMask
        deepCoreAnchorBlend.maskImage = deepCoreMask
        let coreFloorRaisedMask = (deepCoreAnchorBlend.outputImage ?? nearWhiteAnchoredMask)
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)

        return MaskRefinementArtifacts(
            refinedMask: coreFloorRaisedMask,
            edgeBandMask: edgeBandMask,
            edgeGuideMask: edgeGuideMask,
            highlightEdgeMask: highlightEdgeMask,
            hardEdgeMask: hardEdgeMask,
            darkEdgeRiskMask: darkEdgeRiskMask,
            thinStructureMask: thinStructureMask,
            chromaSpillRiskMask: chromaSpillRiskMask
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func applyEdgeDecontamination(
        sourceImage: CIImage,
        refinedMask: CIImage,
        edgeBandMask: CIImage,
        chromaSpillRiskMask: CIImage,
        darkEdgeRiskMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        // R1.2: keep decontam strictly tone-safe and strictly outside the subject.
        // Foreground side (inner ring + core) is force-bypassed.
        let mildlyDecontaminated = sourceImage
        let stronglyDecontaminated = sourceImage.applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputSaturationKey: ProcessingConfig.Decontamination.strongSaturation,
                kCIInputBrightnessKey: 0.0,
                kCIInputContrastKey: 1.0
            ]
        )
        let adaptiveRiskMask = chromaSpillRiskMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.adaptiveRiskBlurRadius])
            .cropped(to: extent)
        let highlightPreserveMask = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: ProcessingConfig.Decontamination.highlightPreserveMinimum, y: ProcessingConfig.Decontamination.highlightPreserveMinimum, z: ProcessingConfig.Decontamination.highlightPreserveMinimum, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: refinedMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.highlightPreserveBlurRadius])
            .cropped(to: extent)
        // Recover 2.1's effective fringe/highlight cleanup with stricter dark-edge protection:
        // spill cleanup stays strong on risky chroma edges, but is suppressed around dark edges
        // to avoid re-introducing whole-foreground washout.
        let darkRiskExpanded = darkEdgeRiskMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.darkRiskExpandedBlurRadius])
            .cropped(to: extent)
        let nonDarkEdgeMask = darkRiskExpanded
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let nonHighlightMask = highlightPreserveMask
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let subjectCoreMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.subjectCoreRadius])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.subjectCoreBlurRadius])
            .cropped(to: extent)

        let nearWhiteProtectMask = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(
                        x: ProcessingConfig.Decontamination.nearWhiteProtectThreshold,
                        y: ProcessingConfig.Decontamination.nearWhiteProtectThreshold,
                        z: ProcessingConfig.Decontamination.nearWhiteProtectThreshold,
                        w: 0
                    ),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            // R2.2: guard near-white core first, avoid over-protecting boundary cleanup zone.
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: subjectCoreMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.nearWhiteProtectBlurRadius])
            .cropped(to: extent)
        let nearWhiteProtectInvertedMask = weightMask(
            nearWhiteProtectMask,
            factor: ProcessingConfig.Decontamination.nearWhiteProtectGuardWeight
        )
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let guardedAdaptiveRiskMask = adaptiveRiskMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonDarkEdgeMask])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonHighlightMask])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nearWhiteProtectInvertedMask])
            .cropped(to: extent)
        let tonedAdaptiveRiskMask = weightMask(
            guardedAdaptiveRiskMask,
            factor: ProcessingConfig.Decontamination.adaptiveRiskWeight
        )
            .cropped(to: extent)
        let adaptiveBlend = CIFilter.blendWithMask()
        adaptiveBlend.inputImage = stronglyDecontaminated
        adaptiveBlend.backgroundImage = mildlyDecontaminated
        adaptiveBlend.maskImage = tonedAdaptiveRiskMask
        let adaptiveDecontaminated = adaptiveBlend.outputImage?.cropped(to: extent) ?? mildlyDecontaminated

        let subjectInnerRing = refinedMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: subjectCoreMask])
            .cropped(to: extent)
        let foregroundBypassMask = subjectCoreMask
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: subjectInnerRing])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let subjectBypassInvertedMask = foregroundBypassMask
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)

        let outerRingMask = edgeBandMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: refinedMask.applyingFilter("CIColorInvert")])
            // R1.2: force bypass of foreground inner/core to prevent washout.
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: subjectBypassInvertedMask])
            // R1.5: further narrow to extreme boundary only, reduce residual gray band.
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.outerRingNarrowRadius])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.outerRingBlurRadius])
            .cropped(to: extent)
        let safeEdgeBand = outerRingMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonDarkEdgeMask])
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    // R1.5: lower blend weight to avoid edge-side haze while preserving contour stability.
                    "inputRVector": CIVector(x: ProcessingConfig.Decontamination.safeEdgeBandWeight, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: ProcessingConfig.Decontamination.safeEdgeBandWeight, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: ProcessingConfig.Decontamination.safeEdgeBandWeight, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: ProcessingConfig.Decontamination.safeEdgeBandWeight),
                    "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ]
            )
            .cropped(to: extent)
        // R1.6: last-mile local cleanup.
        // Only reduce residual gray halo around the upper boundary (top-lid lower edge feel),
        // without touching global band strategy or subject core density.
        let topShiftedMask = refinedMask
            .transformed(by: CGAffineTransform(translationX: 0, y: ProcessingConfig.Decontamination.topShiftY))
            .cropped(to: extent)
        let topInteriorStrip = refinedMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: topShiftedMask])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let topOuterRingInfluence = topInteriorStrip
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.topInfluenceBlurRadius])
            .cropped(to: extent)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: outerRingMask])
            .cropped(to: extent)
        let topGrayBandReductionMask = weightMask(
            topOuterRingInfluence,
            factor: ProcessingConfig.Decontamination.topGrayBandReductionWeight
        )
        let grayBandReducedEdgeBand = safeEdgeBand
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: topGrayBandReductionMask])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)

        let bottomShiftedMask = refinedMask
            .transformed(by: CGAffineTransform(translationX: 0, y: ProcessingConfig.Decontamination.bottomShiftY))
            .cropped(to: extent)
        let bottomInteriorStrip = refinedMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: bottomShiftedMask])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let bottomOuterRingInfluence = bottomInteriorStrip
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.bottomInfluenceBlurRadius])
            .cropped(to: extent)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: outerRingMask])
            .cropped(to: extent)
        let bottomZoneMask = CIImage.empty()
            .applyingFilter(
                "CILinearGradient",
                parameters: [
                    "inputPoint0": CIVector(x: extent.midX, y: extent.minY),
                    "inputPoint1": CIVector(
                        x: extent.midX,
                        y: extent.minY + extent.height * ProcessingConfig.Decontamination.bottomZoneUpperRatio
                    ),
                    "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1),
                    "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 1)
                ]
            )
            .cropped(to: extent)
        let bottomFocusedOuterRingInfluence = bottomOuterRingInfluence
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: bottomZoneMask])
            .cropped(to: extent)
        let bottomGrayFloatSupportMask = weightMask(
            bottomFocusedOuterRingInfluence,
            factor: ProcessingConfig.Decontamination.bottomGrayFloatSupportWeight
        )
        let bottomSupportedEdgeBand = grayBandReducedEdgeBand
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: bottomGrayFloatSupportMask])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)

        let edgeTailCleanupMask = chromaSpillRiskMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: outerRingMask])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonDarkEdgeMask])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nearWhiteProtectInvertedMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Decontamination.edgeTailCleanupBlurRadius])
            .cropped(to: extent)
        let tonedEdgeTailCleanupMask = weightMask(
            edgeTailCleanupMask,
            factor: ProcessingConfig.Decontamination.edgeTailCleanupWeight
        )
        let edgeTailCleanupBlend = CIFilter.blendWithMask()
        edgeTailCleanupBlend.inputImage = stronglyDecontaminated
        edgeTailCleanupBlend.backgroundImage = adaptiveDecontaminated
        edgeTailCleanupBlend.maskImage = tonedEdgeTailCleanupMask
        let tailCleanedAdaptiveImage = edgeTailCleanupBlend.outputImage?.cropped(to: extent) ?? adaptiveDecontaminated

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = tailCleanedAdaptiveImage
        blendFilter.backgroundImage = sourceImage
        blendFilter.maskImage = bottomSupportedEdgeBand
        return blendFilter.outputImage?.cropped(to: extent) ?? sourceImage
    }

    @available(iOS 17.0, *)
    private nonisolated static func applyContactShadow(
        on whiteBackground: CIImage,
        refinedMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let shiftedMask = refinedMask
            .transformed(by: CGAffineTransform(translationX: 0, y: shadowYOffset(for: extent)))
            .cropped(to: extent)

        let blurredShadowMask = shiftedMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: shadowBlurRadius(for: extent)])
            .cropped(to: extent)

        let contactGradient = CIImage.empty()
            .applyingFilter(
                "CILinearGradient",
                parameters: [
                    "inputPoint0": CIVector(x: extent.midX, y: extent.minY + extent.height * 0.52),
                    "inputPoint1": CIVector(x: extent.midX, y: extent.maxY),
                    "inputColor0": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                    "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 1)
                ]
            )
            .cropped(to: extent)

        let contactMask = blurredShadowMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: contactGradient])
            .cropped(to: extent)

        let shadowColorImage = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: shadowOpacity(for: extent))
        ).cropped(to: extent)
        let transparentBackground = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        ).cropped(to: extent)

        let shadowMaskBlend = CIFilter.blendWithMask()
        shadowMaskBlend.inputImage = shadowColorImage
        shadowMaskBlend.backgroundImage = transparentBackground
        shadowMaskBlend.maskImage = contactMask
        let shadowLayer = shadowMaskBlend.outputImage?.cropped(to: extent) ?? transparentBackground

        let sourceOverFilter = CIFilter.sourceOverCompositing()
        sourceOverFilter.inputImage = shadowLayer
        sourceOverFilter.backgroundImage = whiteBackground
        return sourceOverFilter.outputImage?.cropped(to: extent) ?? whiteBackground
    }

    @available(iOS 17.0, *)
    private nonisolated static func applyBoundaryContrastRecovery(
        compositedImage: CIImage,
        sourceImage: CIImage,
        refinedMask: CIImage,
        hardEdgeMask: CIImage,
        darkEdgeRiskMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let innerMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.BoundaryRecovery.innerMaskRadius])
            .cropped(to: extent)
        let outerMask = refinedMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: ProcessingConfig.BoundaryRecovery.outerMaskRadius])
            .cropped(to: extent)
        let boundaryBandMask = outerMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: innerMask])
            .cropped(to: extent)
        let hardBoundaryMask = boundaryBandMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: hardEdgeMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.BoundaryRecovery.hardBoundaryBlurRadius])
            .cropped(to: extent)
        let darkHardBoundaryMask = hardBoundaryMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: darkEdgeRiskMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.BoundaryRecovery.darkHardBoundaryBlurRadius])
            .cropped(to: extent)
        let softBoundaryMask = boundaryBandMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.BoundaryRecovery.softBoundaryBlurRadius])
            .cropped(to: extent)

        let hardEdgeDetailSource = sourceImage
            .applyingFilter(
                "CIUnsharpMask",
                parameters: [
                    "inputRadius": ProcessingConfig.BoundaryRecovery.hardRecoverUnsharpRadius,
                    "inputIntensity": ProcessingConfig.BoundaryRecovery.hardRecoverUnsharpIntensity
                ]
            )
            .cropped(to: extent)
        let hardRecoverBlend = CIFilter.blendWithMask()
        hardRecoverBlend.inputImage = hardEdgeDetailSource
        hardRecoverBlend.backgroundImage = compositedImage
        hardRecoverBlend.maskImage = hardBoundaryMask
        let hardRecoveredImage = hardRecoverBlend.outputImage?.cropped(to: extent) ?? compositedImage

        let darkEdgeDensitySource = sourceImage
            .applyingFilter(
                "CIUnsharpMask",
                parameters: [
                    "inputRadius": ProcessingConfig.BoundaryRecovery.darkDensityUnsharpRadius,
                    "inputIntensity": ProcessingConfig.BoundaryRecovery.darkDensityUnsharpIntensity
                ]
            )
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: ProcessingConfig.BoundaryRecovery.darkDensityBrightness,
                    kCIInputContrastKey: ProcessingConfig.BoundaryRecovery.darkDensityContrast
                ]
            )
            .cropped(to: extent)
        let darkRecoverBlend = CIFilter.blendWithMask()
        darkRecoverBlend.inputImage = darkEdgeDensitySource
        darkRecoverBlend.backgroundImage = hardRecoveredImage
        darkRecoverBlend.maskImage = weightMask(
            darkHardBoundaryMask,
            factor: ProcessingConfig.BoundaryRecovery.darkRecoverWeight
        )
        let darkRecoveredImage = darkRecoverBlend.outputImage?.cropped(to: extent) ?? hardRecoveredImage

        let softEdgeContrastSource = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: 0.0,
                    kCIInputContrastKey: ProcessingConfig.BoundaryRecovery.softRecoverContrast
                ]
            )
            .cropped(to: extent)
        let softMask = weightMask(
            softBoundaryMask,
            factor: ProcessingConfig.BoundaryRecovery.softRecoverWeight
        )
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.BoundaryRecovery.softMaskBlurRadius])
            .cropped(to: extent)
        let softRecoverBlend = CIFilter.blendWithMask()
        softRecoverBlend.inputImage = softEdgeContrastSource
        softRecoverBlend.backgroundImage = darkRecoveredImage
        softRecoverBlend.maskImage = softMask
        return softRecoverBlend.outputImage?.cropped(to: extent) ?? darkRecoveredImage
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildQualityMetadata(
        refinedMask: CIImage,
        edgeBandMask: CIImage,
        edgeGuideMask: CIImage,
        highlightEdgeMask: CIImage,
        hardEdgeMask: CIImage,
        darkEdgeRiskMask: CIImage,
        thinStructureMask: CIImage,
        chromaSpillRiskMask: CIImage,
        outputImage: CIImage,
        sourceImage: CIImage,
        extent: CGRect,
        renderContext: CIContext
    ) -> [String: String] {
        let coverageRatio = averageIntensity(of: refinedMask, extent: extent, renderContext: renderContext)
        let edgeBand = edgeBandMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.7])
            .cropped(to: extent)
        let edgeRatio = averageIntensity(of: edgeBand, extent: extent, renderContext: renderContext)
        let edgeComplexityScore = averageIntensity(
            of: edgeGuideMask.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBand]),
            extent: extent,
            renderContext: renderContext
        )
        let highlightCutRiskScore = averageIntensity(
            of: highlightEdgeMask
                .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBand])
                .cropped(to: extent),
            extent: extent,
            renderContext: renderContext
        )
        let fringeRiskScore = averageIntensity(
            of: chromaSpillRiskMask
                .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBand])
                .cropped(to: extent),
            extent: extent,
            renderContext: renderContext
        )
        let thinDetailPreserveScore = averageIntensity(
            of: thinStructureMask
                .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBand])
                .cropped(to: extent),
            extent: extent,
            renderContext: renderContext
        )
        let hardEdgePresenceScore = averageIntensity(
            of: hardEdgeMask
                .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBand])
                .cropped(to: extent),
            extent: extent,
            renderContext: renderContext
        )
        let darkEdgeRiskScore = averageIntensity(
            of: darkEdgeRiskMask
                .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBand])
                .cropped(to: extent),
            extent: extent,
            renderContext: renderContext
        )
        let foregroundWashoutRiskScore = averageIntensity(
            of: buildForegroundWashoutRiskMask(
                sourceImage: sourceImage,
                outputImage: outputImage,
                subjectMask: refinedMask,
                extent: extent
            ),
            extent: extent,
            renderContext: renderContext
        )
        let darkEdgeWashoutRiskScore = averageIntensity(
            of: buildForegroundWashoutRiskMask(
                sourceImage: sourceImage,
                outputImage: outputImage,
                subjectMask: darkEdgeRiskMask,
                extent: extent
            ),
            extent: extent,
            renderContext: renderContext
        )
        let softEdgeRiskScore = max(0, edgeRatio - edgeComplexityScore * 0.56)
        let thinEdgeRiskScore = max(0, edgeComplexityScore - thinDetailPreserveScore * 0.9)
        let hardEdgeInstabilityRiskScore = max(0, hardEdgePresenceScore * 0.9 - thinDetailPreserveScore * 0.72)
        let hardCaseSignal = hardCaseSignalForResult(
            hardEdgeInstabilityRisk: hardEdgeInstabilityRiskScore,
            foregroundWashoutRisk: foregroundWashoutRiskScore,
            darkEdgeWashoutRisk: darkEdgeWashoutRiskScore,
            fringeRisk: fringeRiskScore,
            highlightCutRisk: highlightCutRiskScore,
            thinEdgeRisk: thinEdgeRiskScore,
            softEdgeRisk: softEdgeRiskScore
        )
        let qualityLevel = qualityLevelForResult(
            coverageRatio: coverageRatio,
            edgeRatio: edgeRatio,
            edgeComplexity: edgeComplexityScore,
            hardEdgeInstabilityRisk: hardEdgeInstabilityRiskScore,
            foregroundWashoutRisk: foregroundWashoutRiskScore,
            darkEdgeWashoutRisk: darkEdgeWashoutRiskScore,
            fringeRisk: fringeRiskScore,
            highlightCutRisk: highlightCutRiskScore,
            thinEdgeRisk: thinEdgeRiskScore,
            softEdgeRisk: softEdgeRiskScore
        )

        return [
            "processor": "VNForegroundMask+EdgeRefineV2.4",
            "foreground_tone_preservation": "enabled",
            "r1_regression_fix": "enabled",
            "r1_decontam_profile": "tone-safe-background-outer-ring-only",
            "r1_subject_core_opacity_anchor": "enabled",
            "r1_21_benefit_recovery": "guarded_adaptive_edge_decontam",
            "r1_highlight_preserve_guard": "enabled",
            "r1_2_foreground_inner_core_bypass": "enabled",
            "r1_3_core_alpha_floor": "raised",
            "r1_3_edge_transition_band": "narrowed",
            "r1_4_refine_thin_edge_preserve": "enabled",
            "r1_4_refine_contact_edge_support": "enabled",
            "r1_4_refine_near_white_core_anchor": "enabled",
            "r1_5_refine_thin_edge_tuning": "enabled",
            "r1_5_refine_contact_edge_tuning": "enabled",
            "r1_5_refine_near_white_core_tuning": "enabled",
            "r2_1_decontam_bottom_gray_float_support": "enabled",
            "r2_1_decontam_near_white_guard": "enabled",
            "r2_1_decontam_edge_tail_cleanup": "enabled",
            "r2_2_bottom_zone_focus": "enabled",
            "r2_2_near_white_core_priority": "enabled",
            "r2_2_tail_cleanup_balance_tuning": "enabled",
            "background": "white+contact-shadow",
            "coverage_ratio": String(format: "%.4f", coverageRatio),
            "edge_ratio": String(format: "%.4f", edgeRatio),
            "edge_complexity_score": String(format: "%.4f", edgeComplexityScore),
            "hard_edge_instability_risk_score": String(format: "%.4f", hardEdgeInstabilityRiskScore),
            "dark_edge_risk_score": String(format: "%.4f", darkEdgeRiskScore),
            "foreground_washout_risk_score": String(format: "%.4f", foregroundWashoutRiskScore),
            "dark_edge_washout_risk_score": String(format: "%.4f", darkEdgeWashoutRiskScore),
            "fringe_risk_score": String(format: "%.4f", fringeRiskScore),
            "highlight_cut_risk_score": String(format: "%.4f", highlightCutRiskScore),
            "thin_edge_risk_score": String(format: "%.4f", thinEdgeRiskScore),
            "soft_edge_risk_score": String(format: "%.4f", softEdgeRiskScore),
            "hard_case_signal": hardCaseSignal.rawValue,
            "quality_level": qualityLevel.rawValue
        ]
    }

    private nonisolated static func makeTinyORTRuntimeSignalMetadata(segmentationMetadata: [String: String]) -> [String: String] {
        let coverageRatio = Double(segmentationMetadata["tiny_ort_signal_coverage_ratio"] ?? "") ?? 0
        let confidenceScore = Double(segmentationMetadata["tiny_ort_signal_confidence_score"] ?? "") ?? 0
        let edgeDensityScore = Double(segmentationMetadata["tiny_ort_signal_edge_density_score"] ?? "") ?? 0

        let thinEdgeRisk = max(0, edgeDensityScore - 0.11)
        let hardEdgeInstabilityRisk = max(0, (1.0 - confidenceScore) - 0.2)
        let foregroundWashoutRisk = max(0, (0.42 - confidenceScore) * 0.6)
        let darkEdgeWashoutRisk = max(0, (0.34 - confidenceScore) * 0.45)
        let fringeRisk = max(0, edgeDensityScore - 0.18)
        let softEdgeRisk = max(0, (0.24 - confidenceScore) * 0.5)

        let baselineHardCaseSignal = hardCaseSignalForResult(
            hardEdgeInstabilityRisk: hardEdgeInstabilityRisk,
            foregroundWashoutRisk: foregroundWashoutRisk,
            darkEdgeWashoutRisk: darkEdgeWashoutRisk,
            fringeRisk: fringeRisk,
            highlightCutRisk: 0,
            thinEdgeRisk: thinEdgeRisk,
            softEdgeRisk: softEdgeRisk
        )
        let baselineQualityLevel = qualityLevelForResult(
            coverageRatio: coverageRatio,
            edgeRatio: edgeDensityScore,
            edgeComplexity: edgeDensityScore,
            hardEdgeInstabilityRisk: hardEdgeInstabilityRisk,
            foregroundWashoutRisk: foregroundWashoutRisk,
            darkEdgeWashoutRisk: darkEdgeWashoutRisk,
            fringeRisk: fringeRisk,
            highlightCutRisk: 0,
            thinEdgeRisk: thinEdgeRisk,
            softEdgeRisk: softEdgeRisk
        )
        let tinyRuntimeQualityLevel: WhiteBackgroundQualityLevel
        if coverageRatio < 0.07 || coverageRatio > 0.58 {
            tinyRuntimeQualityLevel = .risk
        } else if coverageRatio < 0.12
            || coverageRatio > 0.40
            || confidenceScore < 0.985
            || edgeDensityScore > 0.0035 {
            tinyRuntimeQualityLevel = .review
        } else {
            tinyRuntimeQualityLevel = baselineQualityLevel == .risk ? .review : .ready
        }

        let tinyRuntimeHardCaseSignal: WhiteBackgroundHardCaseSignal
        switch tinyRuntimeQualityLevel {
        case .risk:
            tinyRuntimeHardCaseSignal = .hardEdgeInstability
        case .review:
            if coverageRatio < 0.12 {
                tinyRuntimeHardCaseSignal = .thinDetailEdge
            } else if coverageRatio > 0.40 {
                tinyRuntimeHardCaseSignal = .foregroundWashout
            } else if confidenceScore < 0.985 {
                tinyRuntimeHardCaseSignal = .softEdge
            } else {
                tinyRuntimeHardCaseSignal = baselineHardCaseSignal
            }
        case .ready:
            tinyRuntimeHardCaseSignal = .stable
        }

        return [
            "processor": "VNForegroundMask+EdgeRefineV2.4",
            "foreground_tone_preservation": "enabled",
            "r1_regression_fix": "enabled",
            "r1_decontam_profile": "tone-safe-background-outer-ring-only",
            "r1_subject_core_opacity_anchor": "enabled",
            "r1_21_benefit_recovery": "guarded_adaptive_edge_decontam",
            "r1_highlight_preserve_guard": "enabled",
            "r1_2_foreground_inner_core_bypass": "enabled",
            "r1_3_core_alpha_floor": "raised",
            "r1_3_edge_transition_band": "narrowed",
            "r1_4_refine_thin_edge_preserve": "enabled",
            "r1_4_refine_contact_edge_support": "enabled",
            "r1_4_refine_near_white_core_anchor": "enabled",
            "r1_5_refine_thin_edge_tuning": "enabled",
            "r1_5_refine_contact_edge_tuning": "enabled",
            "r1_5_refine_near_white_core_tuning": "enabled",
            "r2_1_decontam_bottom_gray_float_support": "enabled",
            "r2_1_decontam_near_white_guard": "enabled",
            "r2_1_decontam_edge_tail_cleanup": "enabled",
            "r2_2_bottom_zone_focus": "enabled",
            "r2_2_near_white_core_priority": "enabled",
            "r2_2_tail_cleanup_balance_tuning": "enabled",
            "background": "white+contact-shadow",
            "coverage_ratio": String(format: "%.4f", coverageRatio),
            "edge_ratio": String(format: "%.4f", edgeDensityScore),
            "edge_complexity_score": String(format: "%.4f", edgeDensityScore),
            "hard_edge_instability_risk_score": String(format: "%.4f", hardEdgeInstabilityRisk),
            "dark_edge_risk_score": String(format: "%.4f", darkEdgeWashoutRisk),
            "foreground_washout_risk_score": String(format: "%.4f", foregroundWashoutRisk),
            "dark_edge_washout_risk_score": String(format: "%.4f", darkEdgeWashoutRisk),
            "fringe_risk_score": String(format: "%.4f", fringeRisk),
            "highlight_cut_risk_score": "0.0000",
            "thin_edge_risk_score": String(format: "%.4f", thinEdgeRisk),
            "soft_edge_risk_score": String(format: "%.4f", softEdgeRisk),
            "tiny_ort_signal_coverage_ratio": String(format: "%.4f", coverageRatio),
            "tiny_ort_signal_confidence_score": String(format: "%.4f", confidenceScore),
            "tiny_ort_signal_edge_density_score": String(format: "%.4f", edgeDensityScore),
            "hard_case_signal": tinyRuntimeHardCaseSignal.rawValue,
            "quality_level": tinyRuntimeQualityLevel.rawValue
        ]
    }

    private nonisolated static func summarizeTinyORTSignals(
        logitsData: Data,
        width: Int,
        height: Int
    ) -> TinyORTSignalSummary {
        guard width > 0, height > 0 else {
            return TinyORTSignalSummary(coverageRatio: 0, confidenceScore: 0, edgeDensityScore: 0)
        }

        let requiredBytes = width * height * MemoryLayout<Float>.size
        guard logitsData.count >= requiredBytes else {
            return TinyORTSignalSummary(coverageRatio: 0, confidenceScore: 0, edgeDensityScore: 0)
        }

        let pixelCount = width * height
        var binaryMask = [UInt8](repeating: 0, count: pixelCount)
        var foregroundCount = 0
        var confidenceAccum = 0.0

        logitsData.withUnsafeBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            for index in 0..<pixelCount {
                let raw = Double(floatBuffer[index])
                let activated = 1.0 / (1.0 + exp(-raw))
                if activated >= 0.5 {
                    binaryMask[index] = 1
                    foregroundCount += 1
                }
                confidenceAccum += abs(activated - 0.5) * 2.0
            }
        }

        let coverageRatio = Double(foregroundCount) / Double(pixelCount)
        let confidenceScore = confidenceAccum / Double(pixelCount)

        var edgeTransitions = 0
        var totalComparisons = 0
        for y in 0..<height {
            let rowStart = y * width
            if width > 1 {
                for x in 0..<(width - 1) {
                    totalComparisons += 1
                    if binaryMask[rowStart + x] != binaryMask[rowStart + x + 1] {
                        edgeTransitions += 1
                    }
                }
            }
            if y < height - 1 {
                let nextRowStart = (y + 1) * width
                for x in 0..<width {
                    totalComparisons += 1
                    if binaryMask[rowStart + x] != binaryMask[nextRowStart + x] {
                        edgeTransitions += 1
                    }
                }
            }
        }
        let edgeDensityScore = totalComparisons > 0
            ? Double(edgeTransitions) / Double(totalComparisons)
            : 0

        return TinyORTSignalSummary(
            coverageRatio: coverageRatio,
            confidenceScore: confidenceScore,
            edgeDensityScore: edgeDensityScore
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func averageIntensity(
        of image: CIImage,
        extent: CGRect,
        renderContext: CIContext
    ) -> Double {
        let averageImage = image.applyingFilter(
            "CIAreaAverage",
            parameters: [kCIInputExtentKey: CIVector(cgRect: extent)]
        )
        var pixel = [UInt8](repeating: 0, count: 4)
        renderContext.render(
            averageImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return Double(pixel[0]) / 255.0
    }

    private nonisolated static func maskFeatherRadius(for extent: CGRect) -> Double {
        ProcessingConfig.DynamicRadii.maskFeatherRadius(for: extent)
    }

    private nonisolated static func edgeBandRadius(for extent: CGRect) -> Double {
        ProcessingConfig.DynamicRadii.edgeBandRadius(for: extent)
    }

    private nonisolated static func shadowBlurRadius(for extent: CGRect) -> Double {
        ProcessingConfig.DynamicRadii.shadowBlurRadius(for: extent)
    }

    private nonisolated static func shadowYOffset(for extent: CGRect) -> CGFloat {
        ProcessingConfig.DynamicRadii.shadowYOffset(for: extent)
    }

    private nonisolated static func shadowOpacity(for extent: CGRect) -> CGFloat {
        ProcessingConfig.DynamicRadii.shadowOpacity(for: extent)
    }

    private enum WhiteBackgroundQualityLevel: String {
        case ready
        case review
        case risk
    }

    private enum WhiteBackgroundHardCaseSignal: String {
        case stable
        case foregroundWashout
        case darkEdgeWashout
        case hardEdgeInstability
        case fringeEdge
        case highlightCutEdge
        case thinDetailEdge
        case softEdge
    }

    private nonisolated static func qualityLevelForResult(
        coverageRatio: Double,
        edgeRatio: Double,
        edgeComplexity: Double,
        hardEdgeInstabilityRisk: Double,
        foregroundWashoutRisk: Double,
        darkEdgeWashoutRisk: Double,
        fringeRisk: Double,
        highlightCutRisk: Double,
        thinEdgeRisk: Double,
        softEdgeRisk: Double
    ) -> WhiteBackgroundQualityLevel {
        if coverageRatio < ProcessingConfig.Quality.coverageRiskLower || coverageRatio > ProcessingConfig.Quality.coverageRiskUpper {
            return .risk
        }
        if coverageRatio < ProcessingConfig.Quality.coverageReviewLower || coverageRatio > ProcessingConfig.Quality.coverageReviewUpper {
            return .review
        }
        if foregroundWashoutRisk > ProcessingConfig.Quality.riskForegroundWashout
            || darkEdgeWashoutRisk > ProcessingConfig.Quality.riskDarkEdgeWashout
            || hardEdgeInstabilityRisk > ProcessingConfig.Quality.riskHardEdgeInstability
            || fringeRisk > ProcessingConfig.Quality.riskFringe
            || highlightCutRisk > ProcessingConfig.Quality.riskHighlightCut
            || thinEdgeRisk > ProcessingConfig.Quality.riskThinEdge
            || softEdgeRisk > ProcessingConfig.Quality.riskSoftEdge {
            return .risk
        }
        if edgeComplexity > ProcessingConfig.Quality.reviewEdgeComplexity
            || edgeRatio > ProcessingConfig.Quality.reviewEdgeRatio
            || foregroundWashoutRisk > ProcessingConfig.Quality.reviewForegroundWashout
            || darkEdgeWashoutRisk > ProcessingConfig.Quality.reviewDarkEdgeWashout
            || hardEdgeInstabilityRisk > ProcessingConfig.Quality.reviewHardEdgeInstability
            || fringeRisk > ProcessingConfig.Quality.reviewFringe
            || thinEdgeRisk > ProcessingConfig.Quality.reviewThinEdge {
            return .review
        }
        return .ready
    }

    private struct MaskRefinementArtifacts {
        let refinedMask: CIImage
        let edgeBandMask: CIImage
        let edgeGuideMask: CIImage
        let highlightEdgeMask: CIImage
        let hardEdgeMask: CIImage
        let darkEdgeRiskMask: CIImage
        let thinStructureMask: CIImage
        let chromaSpillRiskMask: CIImage
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildEdgeGuideMask(from sourceImage: CIImage, extent: CGRect) -> CIImage {
        let grayscale = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let edges = grayscale
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 2.2])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.7])
            .cropped(to: extent)
        return edges
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func scaleMask(_ image: CIImage, factor: CGFloat) -> CIImage {
        image.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: factor, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: factor, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: factor, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func weightMask(_ image: CIImage, factor: CGFloat) -> CIImage {
        image.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: factor, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: factor, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: factor, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: factor),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
            ]
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildHighlightRiskMask(
        from sourceImage: CIImage,
        edgeBandMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let grayscale = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let brightOnly = grayscale
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0.74, y: 0.74, z: 0.74, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        return brightOnly
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildHardEdgeCandidateMask(
        from sourceImage: CIImage,
        edgeBandMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let hardGradient = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.25])
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 3.1])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0.12, y: 0.12, z: 0.12, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        return hardGradient
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 0.5])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.36])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.45])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildDarkEdgeRiskMask(
        from sourceImage: CIImage,
        edgeBandMask: CIImage,
        hardEdgeMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let grayscale = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let darkRegionMask = grayscale
            .applyingFilter("CIColorInvert")
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0.42, y: 0.42, z: 0.42, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        return darkRegionMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: hardEdgeMask])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildThinStructureMask(
        from edgeGuideMask: CIImage,
        edgeBandMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let normalizedEdges = edgeGuideMask
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0.04, y: 0.04, z: 0.04, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let narrowBand = edgeBandMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.45])
            .cropped(to: extent)
        return normalizedEdges
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: narrowBand])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.35])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildContactEdgeSupportMask(
        from coreMask: CIImage,
        edgeBandMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let shiftedUpCore = coreMask
            .transformed(by: CGAffineTransform(translationX: 0, y: ProcessingConfig.Refinement.contactEdgeShiftY))
            .cropped(to: extent)
        let lowerContactStrip = coreMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: shiftedUpCore])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        return lowerContactStrip
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.contactEdgeSupportBlurRadius])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildNearWhiteCoreMask(
        from sourceImage: CIImage,
        coreMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let grayscale = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let nearWhiteLumaMask = grayscale
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(
                        x: ProcessingConfig.Refinement.nearWhiteCoreThreshold,
                        y: ProcessingConfig.Refinement.nearWhiteCoreThreshold,
                        z: ProcessingConfig.Refinement.nearWhiteCoreThreshold,
                        w: 0
                    ),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        return nearWhiteLumaMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: coreMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Refinement.nearWhiteCoreBlurRadius])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildChromaSpillRiskMask(
        from sourceImage: CIImage,
        edgeBandMask: CIImage,
        highlightMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let amplifiedColor = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 2.2,
                    kCIInputBrightnessKey: 0.0,
                    kCIInputContrastKey: 1.05
                ]
            )
            .cropped(to: extent)
        let grayscale = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let chromaDifference = amplifiedColor
            .applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: grayscale])
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputBrightnessKey: 0,
                    kCIInputContrastKey: 1.2
                ]
            )
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0.06, y: 0.06, z: 0.06, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        let edgeChroma = chromaDifference
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .cropped(to: extent)
        let highlightSuppression = highlightMask
            .applyingFilter("CIColorInvert")
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.75])
            .cropped(to: extent)
        return edgeChroma
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: highlightSuppression])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
    }

    @available(iOS 17.0, *)
    private nonisolated static func applyForegroundFidelityConservation(
        compositedImage: CIImage,
        sourceImage: CIImage,
        refinedMask: CIImage,
        hardEdgeMask: CIImage,
        darkEdgeRiskMask: CIImage,
        extent: CGRect,
        renderContext: CIContext
    ) -> CIImage {
        let washoutRiskMask = buildForegroundWashoutRiskMask(
            sourceImage: sourceImage,
            outputImage: compositedImage,
            subjectMask: refinedMask,
            extent: extent
        )
        let washoutRiskScore = averageIntensity(
            of: washoutRiskMask,
            extent: extent,
            renderContext: renderContext
        )
        let normalizedWashoutRisk = max(
            0,
            min(
                1,
                (washoutRiskScore - ProcessingConfig.Fidelity.washoutRiskNormalizeStart) /
                    ProcessingConfig.Fidelity.washoutRiskNormalizeRange
            )
        )

        let subjectCoreMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.subjectCoreRadius])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.subjectCoreBlurRadius])
            .cropped(to: extent)
        let innerMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.innerMaskRadius])
            .cropped(to: extent)
        let outerMask = refinedMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.outerMaskRadius])
            .cropped(to: extent)
        let boundaryBandMask = outerMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: innerMask])
            .cropped(to: extent)
        let darkBoundaryMask = darkEdgeRiskMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: boundaryBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.darkBoundaryBlurRadius])
            .cropped(to: extent)
        let hardBoundaryMask = hardEdgeMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: boundaryBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.hardBoundaryBlurRadius])
            .cropped(to: extent)

        let subjectToneMask = weightMask(
            subjectCoreMask,
            factor: ProcessingConfig.Fidelity.subjectToneCoreWeightBase + CGFloat(normalizedWashoutRisk) * ProcessingConfig.Fidelity.subjectToneCoreWeightRiskScale
        )
            .applyingFilter(
                "CIAdditionCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: weightMask(
                        washoutRiskMask,
                        factor: ProcessingConfig.Fidelity.subjectToneWashoutWeightBase + CGFloat(normalizedWashoutRisk) * ProcessingConfig.Fidelity.subjectToneWashoutWeightRiskScale
                    )
                ]
            )
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.subjectToneBlurRadius])
            .cropped(to: extent)

        let toneRecoveredSource = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: ProcessingConfig.Fidelity.toneRecoveryBrightnessBase + normalizedWashoutRisk * ProcessingConfig.Fidelity.toneRecoveryBrightnessRiskScale,
                    kCIInputContrastKey: ProcessingConfig.Fidelity.toneRecoveryContrastBase + normalizedWashoutRisk * ProcessingConfig.Fidelity.toneRecoveryContrastRiskScale
                ]
            )
            .cropped(to: extent)
        let toneBlend = CIFilter.blendWithMask()
        toneBlend.inputImage = toneRecoveredSource
        toneBlend.backgroundImage = compositedImage
        toneBlend.maskImage = subjectToneMask
        let toneRecoveredImage = toneBlend.outputImage?.cropped(to: extent) ?? compositedImage

        let combinedMask = weightMask(
            subjectCoreMask,
            factor: ProcessingConfig.Fidelity.combinedCoreWeightBase + CGFloat(normalizedWashoutRisk) * ProcessingConfig.Fidelity.combinedCoreWeightRiskScale
        )
            .applyingFilter(
                "CIAdditionCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: weightMask(
                        hardBoundaryMask,
                        factor: ProcessingConfig.Fidelity.combinedHardWeightBase + CGFloat(normalizedWashoutRisk) * ProcessingConfig.Fidelity.combinedHardWeightRiskScale
                    )
                ]
            )
            .applyingFilter(
                "CIAdditionCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: weightMask(
                        darkBoundaryMask,
                        factor: ProcessingConfig.Fidelity.combinedDarkWeightBase + CGFloat(normalizedWashoutRisk) * ProcessingConfig.Fidelity.combinedDarkWeightRiskScale
                    )
                ]
            )
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.combinedMaskBlurRadius])
            .cropped(to: extent)

        let densityPreservedSource = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: ProcessingConfig.Fidelity.densityRecoveryBrightnessBase + normalizedWashoutRisk * ProcessingConfig.Fidelity.densityRecoveryBrightnessRiskScale,
                    kCIInputContrastKey: ProcessingConfig.Fidelity.densityRecoveryContrastBase + normalizedWashoutRisk * ProcessingConfig.Fidelity.densityRecoveryContrastRiskScale
                ]
            )
            .cropped(to: extent)
        let densityBlend = CIFilter.blendWithMask()
        densityBlend.inputImage = densityPreservedSource
        densityBlend.backgroundImage = toneRecoveredImage
        densityBlend.maskImage = combinedMask
        let densityRecoveredImage = densityBlend.outputImage?.cropped(to: extent) ?? toneRecoveredImage

        let darkEdgeRecoveredSource = sourceImage
            .applyingFilter(
                "CIUnsharpMask",
                parameters: [
                    "inputRadius": ProcessingConfig.Fidelity.darkEdgeRecoveryUnsharpRadius,
                    "inputIntensity": ProcessingConfig.Fidelity.darkEdgeRecoveryUnsharpIntensity
                ]
            )
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: ProcessingConfig.Fidelity.darkEdgeRecoveryBrightness,
                    kCIInputContrastKey: ProcessingConfig.Fidelity.darkEdgeRecoveryContrast
                ]
            )
            .cropped(to: extent)
        let darkEdgeBlend = CIFilter.blendWithMask()
        darkEdgeBlend.inputImage = darkEdgeRecoveredSource
        darkEdgeBlend.backgroundImage = densityRecoveredImage
        darkEdgeBlend.maskImage = weightMask(
            darkBoundaryMask,
            factor: ProcessingConfig.Fidelity.darkEdgeRecoveryMaskWeightBase + CGFloat(normalizedWashoutRisk) * ProcessingConfig.Fidelity.darkEdgeRecoveryMaskWeightRiskScale
        )
        return darkEdgeBlend.outputImage?.cropped(to: extent) ?? densityRecoveredImage
    }

    @available(iOS 17.0, *)
    private nonisolated static func buildForegroundWashoutRiskMask(
        sourceImage: CIImage,
        outputImage: CIImage,
        subjectMask: CIImage,
        extent: CGRect
    ) -> CIImage {
        let sourceGray = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let outputGray = outputImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .cropped(to: extent)
        let sourceDarkness = sourceGray
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let outputDarkness = outputGray
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let darknessLoss = sourceDarkness
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: outputDarkness])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .cropped(to: extent)
        return darknessLoss
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: subjectMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: ProcessingConfig.Fidelity.washoutMaskBlurRadius])
            .cropped(to: extent)
    }

    private nonisolated static func hardCaseSignalForResult(
        hardEdgeInstabilityRisk: Double,
        foregroundWashoutRisk: Double,
        darkEdgeWashoutRisk: Double,
        fringeRisk: Double,
        highlightCutRisk: Double,
        thinEdgeRisk: Double,
        softEdgeRisk: Double
    ) -> WhiteBackgroundHardCaseSignal {
        if darkEdgeWashoutRisk > ProcessingConfig.Quality.hardCaseDarkEdgeWashout {
            return .darkEdgeWashout
        }
        if foregroundWashoutRisk > ProcessingConfig.Quality.hardCaseForegroundWashout {
            return .foregroundWashout
        }
        if hardEdgeInstabilityRisk > ProcessingConfig.Quality.hardCaseHardEdgeInstability {
            return .hardEdgeInstability
        }
        if fringeRisk > ProcessingConfig.Quality.hardCaseFringe, fringeRisk >= highlightCutRisk, fringeRisk >= thinEdgeRisk {
            return .fringeEdge
        }
        if highlightCutRisk > ProcessingConfig.Quality.hardCaseHighlightCut, highlightCutRisk >= thinEdgeRisk {
            return .highlightCutEdge
        }
        if thinEdgeRisk > ProcessingConfig.Quality.hardCaseThinEdge {
            return .thinDetailEdge
        }
        if softEdgeRisk > ProcessingConfig.Quality.hardCaseSoftEdge {
            return .softEdge
        }
        return .stable
    }

}
