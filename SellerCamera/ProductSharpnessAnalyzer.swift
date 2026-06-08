import Foundation

enum ProductSharpnessState: String {
    case sharp
    case slightlySoft
    case blurry
    case lowConfidence
}

struct ProductSharpnessMetrics {
    let sharpnessScore: Double
    let edgeDensity: Double
    let confidence: Double
    let state: ProductSharpnessState
    let reason: String
}

enum ProductSharpnessAnalyzer {
    private static let edgeThreshold = 0.055
    private static let lowTextureEdgeDensity = 0.018
    private static let lowTextureContrast = 0.040
    private static let minimumConfidence = 0.45
    private static let sharpScoreThreshold = 5.8
    private static let sharpEdgeDensityThreshold = 0.065
    private static let slightlySoftScoreThreshold = 3.0
    private static let slightlySoftEdgeDensityThreshold = 0.035

    static func metrics(
        lumaGrid: [Float],
        width: Int,
        height: Int,
        exposureMetrics: ProductAutoExposureMetrics
    ) -> ProductSharpnessMetrics {
        guard width >= 8, height >= 8, lumaGrid.count == width * height else {
            return lowConfidence(score: 0, edgeDensity: 0, confidence: 0, reason: "insufficientSamples")
        }
        guard exposureMetrics.meanLuma >= 0.08, exposureMetrics.shadowRatio <= 0.90 else {
            return lowConfidence(score: 0, edgeDensity: 0, confidence: 0, reason: "tooDark")
        }
        guard exposureMetrics.clippedRatio <= 0.35, exposureMetrics.highlightRatio <= 0.75 else {
            return lowConfidence(score: 0, edgeDensity: 0, confidence: 0, reason: "overexposed")
        }

        let roiWidth = max(6, Int(Double(width) * 0.62))
        let roiHeight = max(6, Int(Double(height) * 0.62))
        let startX = max(1, (width - roiWidth) / 2)
        let endX = min(width - 1, startX + roiWidth)
        let startY = max(1, (height - roiHeight) / 2)
        let endY = min(height - 1, startY + roiHeight)
        guard endX - startX >= 3, endY - startY >= 3 else {
            return lowConfidence(score: 0, edgeDensity: 0, confidence: 0, reason: "insufficientROI")
        }

        var sampleCount = 0
        var lumaSum = 0.0
        var lumaSquaredSum = 0.0
        var gradientSum = 0.0
        var edgeCount = 0

        for y in startY..<endY {
            for x in startX..<endX {
                let index = y * width + x
                let center = Double(lumaGrid[index])
                let left = Double(lumaGrid[index - 1])
                let right = Double(lumaGrid[index + 1])
                let up = Double(lumaGrid[index - width])
                let down = Double(lumaGrid[index + width])
                let gradient = abs(right - left) + abs(down - up)

                sampleCount += 1
                lumaSum += center
                lumaSquaredSum += center * center
                gradientSum += gradient
                if gradient >= edgeThreshold {
                    edgeCount += 1
                }
            }
        }

        guard sampleCount > 0 else {
            return lowConfidence(score: 0, edgeDensity: 0, confidence: 0, reason: "insufficientROI")
        }

        let meanLuma = lumaSum / Double(sampleCount)
        let variance = max(0, (lumaSquaredSum / Double(sampleCount)) - (meanLuma * meanLuma))
        let contrast = sqrt(variance)
        let edgeDensity = Double(edgeCount) / Double(sampleCount)
        let sharpnessScore = (gradientSum / Double(sampleCount)) * 100.0

        guard !(edgeDensity < lowTextureEdgeDensity && contrast < lowTextureContrast) else {
            return lowConfidence(
                score: sharpnessScore,
                edgeDensity: edgeDensity,
                confidence: 0.20,
                reason: "lowTexture"
            )
        }

        let confidence = min(
            1.0,
            max(
                0.0,
                (min(1.0, edgeDensity / 0.075) * 0.48)
                + (min(1.0, contrast / 0.12) * 0.34)
                + (min(1.0, sharpnessScore / 6.0) * 0.18)
            )
        )

        guard confidence >= minimumConfidence else {
            return lowConfidence(
                score: sharpnessScore,
                edgeDensity: edgeDensity,
                confidence: confidence,
                reason: "lowConfidence"
            )
        }

        if sharpnessScore >= sharpScoreThreshold, edgeDensity >= sharpEdgeDensityThreshold {
            return ProductSharpnessMetrics(
                sharpnessScore: sharpnessScore,
                edgeDensity: edgeDensity,
                confidence: confidence,
                state: .sharp,
                reason: "sharpEdges"
            )
        }
        if sharpnessScore >= slightlySoftScoreThreshold, edgeDensity >= slightlySoftEdgeDensityThreshold {
            return ProductSharpnessMetrics(
                sharpnessScore: sharpnessScore,
                edgeDensity: edgeDensity,
                confidence: confidence,
                state: .slightlySoft,
                reason: "moderateEdges"
            )
        }
        return ProductSharpnessMetrics(
            sharpnessScore: sharpnessScore,
            edgeDensity: edgeDensity,
            confidence: confidence,
            state: .blurry,
            reason: "lowSharpness"
        )
    }

    private static func lowConfidence(
        score: Double,
        edgeDensity: Double,
        confidence: Double,
        reason: String
    ) -> ProductSharpnessMetrics {
        ProductSharpnessMetrics(
            sharpnessScore: score,
            edgeDensity: edgeDensity,
            confidence: confidence,
            state: .lowConfidence,
            reason: reason
        )
    }
}
