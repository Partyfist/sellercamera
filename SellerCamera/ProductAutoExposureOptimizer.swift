//
//  ProductAutoExposureOptimizer.swift
//  SellerCamera
//
//  Created by Codex on 2026/5/30.
//

import Foundation

struct ProductAutoExposureMetrics {
    let meanLuma: Float
    let highlightRatio: Float
    let clippedRatio: Float
    let shadowRatio: Float
    let nearWhiteRatio: Float
    let nearWhiteMeanLuma: Float
}

struct ProductAutoExposureRecommendation {
    let targetBias: Float
    let nextBias: Float
    let reason: String
}

final class ProductAutoExposureOptimizer {
    private let minAutoBias: Float = -0.3
    private let maxAutoBias: Float = 0.8
    private let maxStepPerWrite: Float = 0.1
    private let minimumEffectiveDelta: Float = 0.05

    private var candidateTargetBias: Float?
    private var candidateHitCount = 0

    func reset() {
        candidateTargetBias = nil
        candidateHitCount = 0
    }

    func recommendation(
        metrics: ProductAutoExposureMetrics,
        currentBias: Float,
        minimumDeviceBias: Float,
        maximumDeviceBias: Float
    ) -> ProductAutoExposureRecommendation? {
        let rawTarget = targetBias(for: metrics, currentBias: currentBias)
        let autoLowerBound = max(minAutoBias, minimumDeviceBias)
        let autoUpperBound = min(maxAutoBias, maximumDeviceBias)
        guard autoLowerBound <= autoUpperBound else { return nil }

        let deviceClampedTarget = clamp(
            quantize(rawTarget, step: 0.05),
            autoLowerBound,
            autoUpperBound
        )

        if let candidateTargetBias, abs(candidateTargetBias - deviceClampedTarget) < 0.025 {
            candidateHitCount += 1
        } else {
            candidateTargetBias = deviceClampedTarget
            candidateHitCount = 1
        }

        guard candidateHitCount >= 2 else { return nil }

        let delta = deviceClampedTarget - currentBias
        guard abs(delta) >= minimumEffectiveDelta else { return nil }

        let stepped = currentBias + clamp(delta, -maxStepPerWrite, maxStepPerWrite)
        let nextBias = clamp(
            quantize(stepped, step: 0.05),
            minimumDeviceBias,
            maximumDeviceBias
        )
        guard abs(nextBias - currentBias) >= minimumEffectiveDelta else { return nil }

        return ProductAutoExposureRecommendation(
            targetBias: deviceClampedTarget,
            nextBias: nextBias,
            reason: reason(for: metrics)
        )
    }

    private func targetBias(for metrics: ProductAutoExposureMetrics, currentBias: Float) -> Float {
        if metrics.clippedRatio > 0.03 {
            return min(currentBias, 0.0)
        }
        if metrics.highlightRatio > 0.12 {
            return min(currentBias, 0.3)
        }
        if metrics.nearWhiteRatio > 0.20, metrics.nearWhiteMeanLuma < 0.82 {
            return 0.6
        }
        if metrics.meanLuma < 0.45 {
            return 0.4
        }
        if metrics.shadowRatio > 0.35 {
            return 0.3
        }
        // Stable frames hold the current bias to avoid breathing back to a fixed baseline.
        return currentBias
    }

    private func reason(for metrics: ProductAutoExposureMetrics) -> String {
        if metrics.clippedRatio > 0.03 { return "clippedProtection" }
        if metrics.highlightRatio > 0.12 { return "highlightProtection" }
        if metrics.nearWhiteRatio > 0.20, metrics.nearWhiteMeanLuma < 0.82 { return "grayWhiteLift" }
        if metrics.meanLuma < 0.45 { return "darkSceneLift" }
        if metrics.shadowRatio > 0.35 { return "shadowLift" }
        return "stableClean"
    }

    private func quantize(_ value: Float, step: Float) -> Float {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
