//
//  CurrentProjectStore.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class UserDefaultsCurrentProjectStore: CurrentProjectStore {
    static let defaultKey = "sellerCamera.productWorkspace.currentProjectID"

    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = UserDefaultsCurrentProjectStore.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
    }

    var currentProjectID: UUID? {
        guard let rawValue = userDefaults.string(forKey: key) else { return nil }
        return UUID(uuidString: rawValue)
    }

    func setCurrentProject(_ id: UUID?) {
        if let id {
            userDefaults.set(id.uuidString, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}
