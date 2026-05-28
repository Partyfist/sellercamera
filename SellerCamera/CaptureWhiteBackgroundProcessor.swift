//
//  CaptureWhiteBackgroundProcessor.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/1.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision

enum CaptureWhiteBackgroundProcessorError: LocalizedError {
    case unsupportedSystemVersion
    case invalidInputImage
    case subjectMaskUnavailable
    case outputCompositionFailed
    case outputEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSystemVersion:
            return "当前系统版本不支持白底处理"
        case .invalidInputImage:
            return "输入图片不可用"
        case .subjectMaskUnavailable:
            return "未识别到可处理主体"
        case .outputCompositionFailed:
            return "白底合成失败"
        case .outputEncodingFailed:
            return "处理结果编码失败"
        }
    }
}

struct CaptureWhiteBackgroundProcessor {
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
        return try processOnSupportedSystem(confirmedStillPhoto: confirmedStillPhoto)
    }

    @available(iOS 17.0, *)
    private nonisolated static func processOnSupportedSystem(
        confirmedStillPhoto: CaptureStillPhotoResult
    ) throws -> CaptureProcessedPhotoResult {
        guard let inputImage = CIImage(data: confirmedStillPhoto.imageData) else {
            throw CaptureWhiteBackgroundProcessorError.invalidInputImage
        }
        let extent = inputImage.extent.integral

        let request = VNGenerateForegroundInstanceMaskRequest()
        let requestHandler = VNImageRequestHandler(ciImage: inputImage, options: [:])
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
        let refinementArtifacts = refineSubjectMask(maskImage, sourceImage: inputImage, extent: extent)
        let refinedMaskImage = refinementArtifacts.refinedMask
        let decontaminatedSubjectImage = applyEdgeDecontamination(
            sourceImage: inputImage,
            refinedMask: refinedMaskImage,
            edgeBandMask: refinementArtifacts.edgeBandMask,
            chromaSpillRiskMask: refinementArtifacts.chromaSpillRiskMask,
            darkEdgeRiskMask: refinementArtifacts.darkEdgeRiskMask,
            extent: extent
        )
        let whiteBackground = CIImage(
            color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        ).cropped(to: extent)
        let backgroundWithShadow = applyContactShadow(
            on: whiteBackground,
            refinedMask: refinedMaskImage,
            extent: extent
        )

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = decontaminatedSubjectImage
        blendFilter.maskImage = refinedMaskImage
        blendFilter.backgroundImage = backgroundWithShadow

        guard let compositedImage = blendFilter.outputImage else {
            throw CaptureWhiteBackgroundProcessorError.outputCompositionFailed
        }
        let outputImage = applyBoundaryContrastRecovery(
            compositedImage: compositedImage,
            sourceImage: inputImage,
            refinedMask: refinedMaskImage,
            hardEdgeMask: refinementArtifacts.hardEdgeMask,
            darkEdgeRiskMask: refinementArtifacts.darkEdgeRiskMask,
            extent: extent
        )
        let renderContext = CIContext()
        let fidelityPreservedImage = applyForegroundFidelityConservation(
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
        let qualityMetadata = buildQualityMetadata(
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

        return CaptureProcessedPhotoResult(
            sourceStillPhotoID: confirmedStillPhoto.id,
            imageData: outputData,
            pixelSize: CGSize(width: fidelityPreservedImage.extent.width, height: fidelityPreservedImage.extent.height),
            metadata: qualityMetadata
        )
    }

    @available(iOS 17.0, *)
    private nonisolated static func refineSubjectMask(
        _ maskImage: CIImage,
        sourceImage: CIImage,
        extent: CGRect
    ) -> MaskRefinementArtifacts {
        let closedMask = maskImage
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.1])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 1.1])

        let coreMask = closedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.8])
            .cropped(to: extent)
        let expandedMask = closedMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.8])
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
        let scaledEdgeBandDetail = scaleMask(edgeBandDetail, factor: 0.42)
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
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.26])
            .cropped(to: extent)

        let reflectiveTransitionMask = highlightEdgeMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.25])
            .cropped(to: extent)
        let reflectiveProtectedBlend = CIFilter.blendWithMask()
        reflectiveProtectedBlend.inputImage = featheredMask
        reflectiveProtectedBlend.backgroundImage = edgeRefinedMask
        reflectiveProtectedBlend.maskImage = reflectiveTransitionMask
        let reflectiveProtectedMask = (reflectiveProtectedBlend.outputImage ?? edgeRefinedMask)
            .cropped(to: extent)

        let thinStructureBoost = scaleMask(thinStructureMask, factor: 0.24)
        let thinStructureRestoredMask = reflectiveProtectedMask
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: thinStructureBoost])
            .cropped(to: extent)

        let hardEdgeContinuityMask = hardEdgeMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edgeBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.55])
            .cropped(to: extent)
        let hardEdgeStabilizedCandidate = thinStructureRestoredMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 0.62])
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.48])
            .cropped(to: extent)
        let hardEdgeBlend = CIFilter.blendWithMask()
        hardEdgeBlend.inputImage = hardEdgeStabilizedCandidate
        hardEdgeBlend.backgroundImage = thinStructureRestoredMask
        hardEdgeBlend.maskImage = hardEdgeContinuityMask
        let hardEdgeStabilizedMask = (hardEdgeBlend.outputImage ?? thinStructureRestoredMask)
            .cropped(to: extent)

        let finalRefinedMask = hardEdgeStabilizedMask
            .clampedToExtent()
            // R1.3: keep edge smoothing minimal so core area stays dense.
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.08])
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
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.2])
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 0.45])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.06])
            .cropped(to: extent)
        let fullOpacityMask = CIImage(color: .white).cropped(to: extent)
        let anchorBlend = CIFilter.blendWithMask()
        anchorBlend.inputImage = fullOpacityMask
        anchorBlend.backgroundImage = finalRefinedMask
        anchorBlend.maskImage = subjectCoreAnchorMask
        let anchoredRefinedMask = (anchorBlend.outputImage ?? finalRefinedMask)
            .cropped(to: extent)

        // R1.4: raise alpha floor only in deep subject core.
        // Keep edge transition untouched by using a stronger-eroded interior mask.
        let deepCoreMask = coreMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.62])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.04])
            .cropped(to: extent)
        let deepCoreAnchorBlend = CIFilter.blendWithMask()
        deepCoreAnchorBlend.inputImage = fullOpacityMask
        deepCoreAnchorBlend.backgroundImage = anchoredRefinedMask
        deepCoreAnchorBlend.maskImage = deepCoreMask
        let coreFloorRaisedMask = (deepCoreAnchorBlend.outputImage ?? anchoredRefinedMask)
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
                kCIInputSaturationKey: 0.992,
                kCIInputBrightnessKey: 0.0,
                kCIInputContrastKey: 1.0
            ]
        )
        let adaptiveRiskMask = chromaSpillRiskMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.55])
            .cropped(to: extent)
        let highlightPreserveMask = sourceImage
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter(
                "CIColorClamp",
                parameters: [
                    "inputMinComponents": CIVector(x: 0.78, y: 0.78, z: 0.78, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
                ]
            )
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: refinedMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.55])
            .cropped(to: extent)
        // Recover 2.1's effective fringe/highlight cleanup with stricter dark-edge protection:
        // spill cleanup stays strong on risky chroma edges, but is suppressed around dark edges
        // to avoid re-introducing whole-foreground washout.
        let darkRiskExpanded = darkEdgeRiskMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.9])
            .cropped(to: extent)
        let nonDarkEdgeMask = darkRiskExpanded
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let nonHighlightMask = highlightPreserveMask
            .applyingFilter("CIColorInvert")
            .cropped(to: extent)
        let guardedAdaptiveRiskMask = adaptiveRiskMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonDarkEdgeMask])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonHighlightMask])
            .cropped(to: extent)
        let tonedAdaptiveRiskMask = weightMask(guardedAdaptiveRiskMask, factor: 0.3)
            .cropped(to: extent)
        let adaptiveBlend = CIFilter.blendWithMask()
        adaptiveBlend.inputImage = stronglyDecontaminated
        adaptiveBlend.backgroundImage = mildlyDecontaminated
        adaptiveBlend.maskImage = tonedAdaptiveRiskMask
        let adaptiveDecontaminated = adaptiveBlend.outputImage?.cropped(to: extent) ?? mildlyDecontaminated

        let subjectCoreMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 1.25])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.35])
            .cropped(to: extent)
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
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.88])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.11])
            .cropped(to: extent)
        let safeEdgeBand = outerRingMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: nonDarkEdgeMask])
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    // R1.5: lower blend weight to avoid edge-side haze while preserving contour stability.
                    "inputRVector": CIVector(x: 0.34, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.34, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.34, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.34),
                    "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
                ]
            )
            .cropped(to: extent)
        // R1.6: last-mile local cleanup.
        // Only reduce residual gray halo around the upper boundary (top-lid lower edge feel),
        // without touching global band strategy or subject core density.
        let topShiftedMask = refinedMask
            .transformed(by: CGAffineTransform(translationX: 0, y: -1.9))
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
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.68])
            .cropped(to: extent)
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: outerRingMask])
            .cropped(to: extent)
        let topGrayBandReductionMask = weightMask(topOuterRingInfluence, factor: 0.38)
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

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = adaptiveDecontaminated
        blendFilter.backgroundImage = sourceImage
        blendFilter.maskImage = grayBandReducedEdgeBand
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
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.95])
            .cropped(to: extent)
        let outerMask = refinedMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.65])
            .cropped(to: extent)
        let boundaryBandMask = outerMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: innerMask])
            .cropped(to: extent)
        let hardBoundaryMask = boundaryBandMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: hardEdgeMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.75])
            .cropped(to: extent)
        let darkHardBoundaryMask = hardBoundaryMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: darkEdgeRiskMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.62])
            .cropped(to: extent)
        let softBoundaryMask = boundaryBandMask
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.1])
            .cropped(to: extent)

        let hardEdgeDetailSource = sourceImage
            .applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 0.85, "inputIntensity": 0.34])
            .cropped(to: extent)
        let hardRecoverBlend = CIFilter.blendWithMask()
        hardRecoverBlend.inputImage = hardEdgeDetailSource
        hardRecoverBlend.backgroundImage = compositedImage
        hardRecoverBlend.maskImage = hardBoundaryMask
        let hardRecoveredImage = hardRecoverBlend.outputImage?.cropped(to: extent) ?? compositedImage

        let darkEdgeDensitySource = sourceImage
            .applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 0.7, "inputIntensity": 0.24])
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: -0.006,
                    kCIInputContrastKey: 1.035
                ]
            )
            .cropped(to: extent)
        let darkRecoverBlend = CIFilter.blendWithMask()
        darkRecoverBlend.inputImage = darkEdgeDensitySource
        darkRecoverBlend.backgroundImage = hardRecoveredImage
        darkRecoverBlend.maskImage = weightMask(darkHardBoundaryMask, factor: 0.52)
        let darkRecoveredImage = darkRecoverBlend.outputImage?.cropped(to: extent) ?? hardRecoveredImage

        let softEdgeContrastSource = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: 0.0,
                    kCIInputContrastKey: 1.025
                ]
            )
            .cropped(to: extent)
        let softMask = weightMask(softBoundaryMask, factor: 0.34)
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.8])
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
            "segmentation_provider": "vision",
            "segmentation_request": "VNGenerateForegroundInstanceMaskRequest",
            "mainline_model_policy": "vision_only",
            "foreground_tone_preservation": "enabled",
            "r1_regression_fix": "enabled",
            "r1_decontam_profile": "tone-safe-background-outer-ring-only",
            "r1_subject_core_opacity_anchor": "enabled",
            "r1_21_benefit_recovery": "guarded_adaptive_edge_decontam",
            "r1_highlight_preserve_guard": "enabled",
            "r1_2_foreground_inner_core_bypass": "enabled",
            "r1_3_core_alpha_floor": "raised",
            "r1_3_edge_transition_band": "narrowed",
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
            "hard_case_hint": hardCaseHintText(for: hardCaseSignal),
            "quality_level": qualityLevel.rawValue,
            "quality_hint": qualityHintText(for: qualityLevel)
        ]
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
        max(0.8, min(2.2, Double(min(extent.width, extent.height)) / 1200))
    }

    private nonisolated static func edgeBandRadius(for extent: CGRect) -> Double {
        max(1.2, min(3.5, Double(min(extent.width, extent.height)) / 640))
    }

    private nonisolated static func shadowBlurRadius(for extent: CGRect) -> Double {
        max(2.2, min(10.0, Double(min(extent.width, extent.height)) * 0.012))
    }

    private nonisolated static func shadowYOffset(for extent: CGRect) -> CGFloat {
        max(2, extent.height * 0.006)
    }

    private nonisolated static func shadowOpacity(for extent: CGRect) -> CGFloat {
        let normalized = max(0, min(1, extent.width / 1800))
        return 0.07 + normalized * 0.02
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
        if coverageRatio < 0.015 || coverageRatio > 0.93 {
            return .risk
        }
        if coverageRatio < 0.04 || coverageRatio > 0.84 {
            return .review
        }
        if foregroundWashoutRisk > 0.14 || darkEdgeWashoutRisk > 0.13 || hardEdgeInstabilityRisk > 0.12 || fringeRisk > 0.18 || highlightCutRisk > 0.2 || thinEdgeRisk > 0.09 || softEdgeRisk > 0.075 {
            return .risk
        }
        if edgeComplexity > 0.14 || edgeRatio > 0.11 || foregroundWashoutRisk > 0.09 || darkEdgeWashoutRisk > 0.08 || hardEdgeInstabilityRisk > 0.075 || fringeRisk > 0.12 || thinEdgeRisk > 0.055 {
            return .review
        }
        return .ready
    }

    private nonisolated static func qualityHintText(for qualityLevel: WhiteBackgroundQualityLevel) -> String {
        switch qualityLevel {
        case .ready:
            return "白底质量可直接使用"
        case .review:
            return "白底边缘建议复核"
        case .risk:
            return "白底风险较高，建议补拍"
        }
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
        let normalizedWashoutRisk = max(0, min(1, (washoutRiskScore - 0.025) / 0.23))

        let subjectCoreMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 1.45])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.75])
            .cropped(to: extent)
        let innerMask = refinedMask
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 0.85])
            .cropped(to: extent)
        let outerMask = refinedMask
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.45])
            .cropped(to: extent)
        let boundaryBandMask = outerMask
            .applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: innerMask])
            .cropped(to: extent)
        let darkBoundaryMask = darkEdgeRiskMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: boundaryBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.72])
            .cropped(to: extent)
        let hardBoundaryMask = hardEdgeMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: boundaryBandMask])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.58])
            .cropped(to: extent)

        let subjectToneMask = weightMask(
            subjectCoreMask,
            factor: 0.12 + CGFloat(normalizedWashoutRisk) * 0.45
        )
            .applyingFilter(
                "CIAdditionCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: weightMask(
                        washoutRiskMask,
                        factor: 0.1 + CGFloat(normalizedWashoutRisk) * 0.42
                    )
                ]
            )
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.72])
            .cropped(to: extent)

        let toneRecoveredSource = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: -0.001 - normalizedWashoutRisk * 0.012,
                    kCIInputContrastKey: 1.015 + normalizedWashoutRisk * 0.055
                ]
            )
            .cropped(to: extent)
        let toneBlend = CIFilter.blendWithMask()
        toneBlend.inputImage = toneRecoveredSource
        toneBlend.backgroundImage = compositedImage
        toneBlend.maskImage = subjectToneMask
        let toneRecoveredImage = toneBlend.outputImage?.cropped(to: extent) ?? compositedImage

        let combinedMask = weightMask(subjectCoreMask, factor: 0.14 + CGFloat(normalizedWashoutRisk) * 0.14)
            .applyingFilter(
                "CIAdditionCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: weightMask(
                        hardBoundaryMask,
                        factor: 0.24 + CGFloat(normalizedWashoutRisk) * 0.18
                    )
                ]
            )
            .applyingFilter(
                "CIAdditionCompositing",
                parameters: [
                    kCIInputBackgroundImageKey: weightMask(
                        darkBoundaryMask,
                        factor: 0.48 + CGFloat(normalizedWashoutRisk) * 0.22
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
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.65])
            .cropped(to: extent)

        let densityPreservedSource = sourceImage
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: -0.003 - normalizedWashoutRisk * 0.009,
                    kCIInputContrastKey: 1.02 + normalizedWashoutRisk * 0.06
                ]
            )
            .cropped(to: extent)
        let densityBlend = CIFilter.blendWithMask()
        densityBlend.inputImage = densityPreservedSource
        densityBlend.backgroundImage = toneRecoveredImage
        densityBlend.maskImage = combinedMask
        let densityRecoveredImage = densityBlend.outputImage?.cropped(to: extent) ?? toneRecoveredImage

        let darkEdgeRecoveredSource = sourceImage
            .applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 0.72, "inputIntensity": 0.18])
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 1.0,
                    kCIInputBrightnessKey: -0.007,
                    kCIInputContrastKey: 1.04
                ]
            )
            .cropped(to: extent)
        let darkEdgeBlend = CIFilter.blendWithMask()
        darkEdgeBlend.inputImage = darkEdgeRecoveredSource
        darkEdgeBlend.backgroundImage = densityRecoveredImage
        darkEdgeBlend.maskImage = weightMask(
            darkBoundaryMask,
            factor: 0.46 + CGFloat(normalizedWashoutRisk) * 0.24
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
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.75])
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
        if darkEdgeWashoutRisk > 0.12 {
            return .darkEdgeWashout
        }
        if foregroundWashoutRisk > 0.11 {
            return .foregroundWashout
        }
        if hardEdgeInstabilityRisk > 0.09 {
            return .hardEdgeInstability
        }
        if fringeRisk > 0.16, fringeRisk >= highlightCutRisk, fringeRisk >= thinEdgeRisk {
            return .fringeEdge
        }
        if highlightCutRisk > 0.19, highlightCutRisk >= thinEdgeRisk {
            return .highlightCutEdge
        }
        if thinEdgeRisk > 0.065 {
            return .thinDetailEdge
        }
        if softEdgeRisk > 0.075 {
            return .softEdge
        }
        return .stable
    }

    private nonisolated static func hardCaseHintText(for hardCaseSignal: WhiteBackgroundHardCaseSignal) -> String {
        switch hardCaseSignal {
        case .stable:
            return "常见商品路径"
        case .foregroundWashout:
            return "主体有泛白风险，建议复核"
        case .darkEdgeWashout:
            return "深色边缘有发灰风险，建议复核"
        case .hardEdgeInstability:
            return "硬边连续性风险，建议复核"
        case .fringeEdge:
            return "边缘有溢色风险，建议复核"
        case .highlightCutEdge:
            return "反光边界风险，建议复核"
        case .thinDetailEdge:
            return "细边缘易丢失，建议复核"
        case .softEdge:
            return "软边缘/弱透明风险"
        }
    }
}
