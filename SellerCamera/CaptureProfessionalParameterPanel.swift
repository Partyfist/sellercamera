//
//  CaptureProfessionalParameterPanel.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/3.
//

import SwiftUI

enum CaptureProfessionalParameterKind: String, CaseIterable, Identifiable {
    case focus
    case whiteBalance
    case tint
    case iso
    case shutter
    case exposureCompensation
    case ratio
    case pixel
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .whiteBalance:
            return "WB"
        case .tint:
            return "Tint"
        case .iso:
            return "ISO"
        case .shutter:
            return "Shutter"
        case .exposureCompensation:
            return "EV"
        case .ratio:
            return "Ratio"
        case .pixel:
            return "Pixel"
        case .settings:
            return "更多"
        }
    }
}

enum CaptureProfessionalParameterMode {
    case auto
    case manual
    case locked
    case pending
    case disabled

    var text: String {
        switch self {
        case .auto:
            return "Auto"
        case .manual:
            return "Manual"
        case .locked:
            return "Locked"
        case .pending:
            return "Pending"
        case .disabled:
            return "Unavailable"
        }
    }

    // 主条使用更短状态词，降低小屏拥挤；语义与 text 保持一致。
    var compactText: String {
        switch self {
        case .auto:
            return "Auto"
        case .manual:
            return "Man"
        case .locked:
            return "Lock"
        case .pending:
            return "Pend"
        case .disabled:
            return "N/A"
        }
    }
}

struct CaptureProfessionalParameterState {
    let kind: CaptureProfessionalParameterKind
    let valueText: String
    let mode: CaptureProfessionalParameterMode
    let isAdjustable: Bool
    let canUseAuto: Bool
    let canReset: Bool
    let hintText: String
    let dialRange: ClosedRange<Double>
    let dialValue: Double
    let dialStep: Double
    let leftLabel: String
    let centerLabel: String
    let rightLabel: String
}
