//
//  PhotoFileFormatDetector.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated enum PhotoFileFormatDetector {
    static func fileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(16))
        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] == 0xD8 {
            return "jpg"
        }
        if bytes.count >= 12 {
            let brandData = Data(bytes[8..<12])
            if let brand = String(data: brandData, encoding: .ascii),
               ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand) {
                return "heic"
            }
        }
        if bytes.count >= 4 {
            let tiffLittle = bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00
            let tiffBig = bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A
            if tiffLittle || tiffBig {
                return "dng"
            }
        }
        return "jpg"
    }
}
