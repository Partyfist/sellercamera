//
//  ProjectNameGenerator.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class DefaultProjectNameGenerator: ProjectNameGenerating {
    private let dateFormatter: DateFormatter

    init(calendar: Calendar = Calendar(identifier: .gregorian), locale: Locale = Locale(identifier: "zh_Hans_CN")) {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = formatter
    }

    func generateName(existingNames: [String], date: Date) -> String {
        let prefix = "商品 \(dateFormatter.string(from: date))"
        let pattern = #"^\#(prefix) ([0-9]{3})$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let maxIndex = existingNames.reduce(0) { currentMax, name in
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            guard let match = regex?.firstMatch(in: name, range: range),
                  match.numberOfRanges == 2,
                  let numberRange = Range(match.range(at: 1), in: name),
                  let number = Int(name[numberRange]) else {
                return currentMax
            }
            return max(currentMax, number)
        }
        return "\(prefix) \(String(format: "%03d", maxIndex + 1))"
    }
}
