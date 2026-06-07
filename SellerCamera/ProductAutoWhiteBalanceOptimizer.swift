//
//  ProductAutoWhiteBalanceOptimizer.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/7.
//

import Foundation

struct ProductAutoWhiteBalanceMetrics {
    let nearWhiteSampleCount: Int
    let nearWhiteRatio: Float
    let meanRed: Float
    let meanGreen: Float
    let meanBlue: Float
    let meanLuma: Float
    let redBlueDelta: Float
    let greenCast: Float
    let confidence: Float
}

struct ProductAutoWhiteBalanceRecommendation {
    let targetTemperature: Float
    let nextTemperature: Float
    let reason: String
    let stableHitCount: Int
}

final class ProductAutoWhiteBalanceOptimizer {
    private let minimumAutoTemperature: Float = 3000
    private let maximumAutoTemperature: Float = 7500
    private let singleStepKelvin: Float = 100
    private let minimumEffectiveDelta: Float = 75
    private let stableHitThreshold = 3
    private let minimumConfidence: Float = 0.30
    private let castThreshold: Float = 0.055
    private let greenCastThreshold: Float = 0.07

    private var candidateTargetTemperature: Float?
    private var candidateHitCount = 0
    private var lastDecisionReason = "reset"

    var debugStateSummary: String {
        "decision=\(lastDecisionReason) stableHitCount=\(candidateHitCount)"
    }

    func reset() {
        candidateTargetTemperature = nil
        candidateHitCount = 0
        lastDecisionReason = "reset"
    }

    func recommendation(
        metrics: ProductAutoWhiteBalanceMetrics,
        currentTemperature: Float,
        minimumTemperature: Float,
        maximumTemperature: Float
    ) -> ProductAutoWhiteBalanceRecommendation? {
        guard metrics.confidence >= minimumConfidence else {
            lastDecisionReason = "lowConfidence"
            candidateTargetTemperature = nil
            candidateHitCount = 0
            return nil
        }

        guard abs(metrics.greenCast) <= greenCastThreshold else {
            lastDecisionReason = "greenCastHold"
            candidateTargetTemperature = nil
            candidateHitCount = 0
            return nil
        }

        guard abs(metrics.redBlueDelta) >= castThreshold else {
            lastDecisionReason = "neutralHold"
            candidateTargetTemperature = nil
            candidateHitCount = 0
            return nil
        }

        let correction = correctionKelvin(for: metrics.redBlueDelta)
        let rawTarget: Float
        let reason: String
        if metrics.redBlueDelta > 0 {
            rawTarget = currentTemperature - correction
            reason = "warmCastCoolDown"
        } else {
            rawTarget = currentTemperature + correction
            reason = "coolCastWarmUp"
        }
        lastDecisionReason = reason

        let lowerBound = max(minimumAutoTemperature, minimumTemperature)
        let upperBound = min(maximumAutoTemperature, maximumTemperature)
        guard lowerBound <= upperBound else { return nil }

        let targetTemperature = clamp(
            quantize(rawTarget, step: 50),
            lowerBound,
            upperBound
        )

        if let candidateTargetTemperature, abs(candidateTargetTemperature - targetTemperature) < 50 {
            candidateHitCount += 1
        } else {
            candidateTargetTemperature = targetTemperature
            candidateHitCount = 1
        }

        guard candidateHitCount >= stableHitThreshold else { return nil }

        let delta = targetTemperature - currentTemperature
        guard abs(delta) >= minimumEffectiveDelta else { return nil }

        let stepped = currentTemperature + clamp(delta, -singleStepKelvin, singleStepKelvin)
        let nextTemperature = clamp(
            quantize(stepped, step: 50),
            lowerBound,
            upperBound
        )
        guard abs(nextTemperature - currentTemperature) >= minimumEffectiveDelta else { return nil }

        return ProductAutoWhiteBalanceRecommendation(
            targetTemperature: targetTemperature,
            nextTemperature: nextTemperature,
            reason: reason,
            stableHitCount: candidateHitCount
        )
    }

    private func correctionKelvin(for redBlueDelta: Float) -> Float {
        let normalized = min(max(abs(redBlueDelta), castThreshold), 0.18)
        let progress = (normalized - castThreshold) / (0.18 - castThreshold)
        return 200 + progress * 400
    }

    private func quantize(_ value: Float, step: Float) -> Float {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
