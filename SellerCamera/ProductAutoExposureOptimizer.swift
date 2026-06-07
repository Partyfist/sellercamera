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
    let stableBrightCount: Int
}

final class ProductAutoExposureOptimizer {
    private let minAutoBias: Float = -0.3
    private let maxAutoBias: Float = 0.8
    private let maxStepPerWrite: Float = 0.1
    private let minimumEffectiveDelta: Float = 0.05
    private let baselineAutoBias: Float = 0.15
    private let stableBrightHitThreshold = 5
    private let stableBrightDecayStep: Float = 0.05

    private var candidateTargetBias: Float?
    private var candidateHitCount = 0
    private var stableBrightHitCount = 0
    private var lastDecisionReason = "reset"

    var debugStateSummary: String {
        "decision=\(lastDecisionReason) stableBrightCount=\(stableBrightHitCount)"
    }

    func reset() {
        candidateTargetBias = nil
        candidateHitCount = 0
        stableBrightHitCount = 0
        lastDecisionReason = "reset"
    }

    func recommendation(
        metrics: ProductAutoExposureMetrics,
        currentBias: Float,
        minimumDeviceBias: Float,
        maximumDeviceBias: Float
    ) -> ProductAutoExposureRecommendation? {
        let decision = targetBias(for: metrics, currentBias: currentBias)
        lastDecisionReason = decision.reason
        let autoLowerBound = max(minAutoBias, minimumDeviceBias)
        let autoUpperBound = min(maxAutoBias, maximumDeviceBias)
        guard autoLowerBound <= autoUpperBound else { return nil }

        let deviceClampedTarget = clamp(
            quantize(decision.targetBias, step: 0.05),
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
            reason: decision.reason,
            stableBrightCount: stableBrightHitCount
        )
    }

    private func targetBias(for metrics: ProductAutoExposureMetrics, currentBias: Float) -> (targetBias: Float, reason: String) {
        if metrics.clippedRatio > 0.025 {
            stableBrightHitCount = 0
            return (min(currentBias, 0.0), "clippedGuard")
        }
        if metrics.highlightRatio > 0.12 {
            stableBrightHitCount = 0
            return (min(currentBias, 0.25), "highlightGuard")
        }
        if metrics.nearWhiteRatio > 0.18, metrics.nearWhiteMeanLuma < 0.84 {
            stableBrightHitCount = 0
            return (0.65, "grayWhiteLift")
        }
        if metrics.meanLuma < 0.45 {
            stableBrightHitCount = 0
            return (0.45, "darkSceneLift")
        }
        if metrics.shadowRatio > 0.35 {
            stableBrightHitCount = 0
            return (0.3, "shadowLift")
        }
        if isStableBright(metrics), currentBias > baselineAutoBias + minimumEffectiveDelta {
            stableBrightHitCount += 1
            if stableBrightHitCount >= stableBrightHitThreshold {
                return (max(currentBias - stableBrightDecayStep, baselineAutoBias), "stableBrightDecay")
            }
            return (currentBias, "stableBrightHold")
        }

        stableBrightHitCount = 0
        // Stable frames hold the current bias to avoid breathing back to a fixed baseline.
        return (currentBias, "stableHold")
    }

    private func isStableBright(_ metrics: ProductAutoExposureMetrics) -> Bool {
        let whiteIsAlreadyClean = metrics.nearWhiteRatio < 0.16 || metrics.nearWhiteMeanLuma >= 0.84
        return metrics.meanLuma >= 0.54
            && metrics.shadowRatio < 0.22
            && metrics.highlightRatio < 0.09
            && metrics.clippedRatio < 0.01
            && whiteIsAlreadyClean
    }

    private func quantize(_ value: Float, step: Float) -> Float {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
