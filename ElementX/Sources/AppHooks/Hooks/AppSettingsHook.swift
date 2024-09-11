//
// Copyright 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Foundation

protocol AppSettingsHookProtocol {
    func configure(_ appSettings: AppSettings) -> AppSettings
}

struct DefaultAppSettingsHook: AppSettingsHookProtocol {
    func configure(_ appSettings: AppSettings) -> AppSettings { appSettings }
}