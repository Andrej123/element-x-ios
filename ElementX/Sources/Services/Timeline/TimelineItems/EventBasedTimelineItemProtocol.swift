//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import UIKit

protocol EventBasedTimelineItemProtocol: RoomTimelineItemProtocol, CustomStringConvertible {
    var timestamp: String { get }
    var isOutgoing: Bool { get }
    var isEditable: Bool { get }
    
    var sender: TimelineItemSender { get }
    
    var body: String { get }
    
    var properties: RoomTimelineItemProperties { get }
}

extension EventBasedTimelineItemProtocol {
    var description: String {
        "\(String(describing: Self.self)): id: \(id), timestamp: \(timestamp), isOutgoing: \(isOutgoing), properties: \(properties)"
    }

    var hasFailedToSend: Bool {
        properties.deliveryStatus == .sendingFailed
    }

    var isMessage: Bool {
        self is EventBasedMessageTimelineItemProtocol
    }

    var isLocation: Bool {
        self is LocationRoomTimelineItem
    }

    var isRedacted: Bool {
        self is RedactedRoomTimelineItem
    }

    var hasFailedDecryption: Bool {
        self is EncryptedRoomTimelineItem
    }
}