import SwiftUI

/// Push-to-dictate mic button that fills the chat draft via on-device speech.
struct MicButton: View {
    @Bindable var convo: ConversationModel
    @Environment(SpeechService.self) private var speech

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                .font(.title3)
                .foregroundStyle(speech.isRecording ? .red : .secondary)
        }
        .accessibilityLabel(speech.isRecording ? "Stop dictation" : "Start voice dictation")
    }

    private func toggle() async {
        if speech.isRecording {
            speech.stopDictation()
        } else {
            guard await speech.requestAuthorization() else { return }
            speech.startDictation { partial in convo.draft = partial }
        }
    }
}
