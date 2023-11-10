//
// Copyright 2023 New Vector Ltd
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

import Compound
import SwiftUI

enum VoiceMessageRecordingButtonMode {
    case idle
    case recording
}

struct VoiceMessageRecordingButton: View {
    let mode: VoiceMessageRecordingButtonMode
    var startRecording: (() -> Void)?
    var stopRecording: (() -> Void)?
    
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator()
    @ScaledMetric(relativeTo: .title) private var idleImageSize = 16
    @ScaledMetric(relativeTo: .title) private var idleImagePadding = 10
    
    @ScaledMetric(relativeTo: .title) private var recordingImageSize = 24
    @ScaledMetric(relativeTo: .title) private var recordingImagePadding = 6
    
    var body: some View {
        Button {
            impactFeedbackGenerator.impactOccurred()
            switch mode {
            case .idle:
                startRecording?()
            case .recording:
                stopRecording?()
            }
        } label: {
            switch mode {
            case .idle:
                CompoundIcon(\.micOnOutline, size: .medium, relativeTo: .title)
                    .foregroundColor(.compound.iconSecondary)
                    .frame(width: idleImageSize, height: idleImageSize)
                    .padding(idleImagePadding)
                    .padding(4)
            case .recording:
                Asset.Images.stopRecording.swiftUIImage
                    .resizable()
                    .foregroundColor(.compound.iconOnSolidPrimary)
                    .frame(width: recordingImageSize, height: recordingImageSize)
                    .padding(recordingImagePadding)
                    .background(
                        Circle()
                            .foregroundColor(.compound.bgActionPrimaryRest)
                    )
                    .padding(4)
            }
        }
        .buttonStyle(VoiceMessageRecordingButtonStyle())
        .accessibilityLabel(mode == .idle ? L10n.a11yVoiceMessageRecord : L10n.a11yVoiceMessageStopRecording)
    }
}

private struct VoiceMessageRecordingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct VoiceMessageRecordingButton_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        HStack {
            VoiceMessageRecordingButton(mode: .idle)
            
            VoiceMessageRecordingButton(mode: .recording)
        }
    }
}