// ============================================================================
// SelfDiscussionView.swift — Self-discussion mode: AI debates itself
// ============================================================================

import SwiftUI

struct SelfDiscussionView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    @State private var topic = ""
    @State private var turns = 3
    @State private var perspectiveA = "Argue strongly IN FAVOR of this topic. Be persuasive and specific."
    @State private var perspectiveB = "Argue strongly AGAINST this topic. Counter the previous arguments."
    @State private var languageA = "en-GB"
    @State private var languageB = "en-GB"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.purple)
                Text("Self-Discussion")
                    .font(.headline)
                Spacer()
            }

            Text("The AI will debate itself, alternating between two perspectives.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Topic
            VStack(alignment: .leading, spacing: 4) {
                Text("Topic:")
                    .font(.caption)
                    .fontWeight(.medium)
                TextField("e.g. 'Is AI consciousness possible?'", text: $topic)
                    .textFieldStyle(.roundedBorder)
            }

            // Turns
            HStack {
                Text("Turns:")
                    .font(.caption)
                    .fontWeight(.medium)
                Picker("", selection: $turns) {
                    ForEach([2, 3, 5, 7, 10], id: \.self) { n in
                        Text("\(n) turns (\(n * 2) messages)").tag(n)
                    }
                }
                .frame(width: 200)
            }

            // Perspectives
            VStack(alignment: .leading, spacing: 4) {
                Text("Perspective A (odd turns):")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                Picker("Language", selection: $languageA) {
                    ForEach(TTSManager.preferredVoices) { voice in
                        Text(voice.label).tag(voice.languageCode)
                    }
                }
                .pickerStyle(.menu)
                TextField("System prompt for side A", text: $perspectiveA)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Perspective B (even turns):")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                Picker("Language", selection: $languageB) {
                    ForEach(TTSManager.preferredVoices) { voice in
                        Text(voice.label).tag(voice.languageCode)
                    }
                }
                .pickerStyle(.menu)
                TextField("System prompt for side B", text: $perspectiveB)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            // Actions
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Start Discussion") {
                    dismiss()
                    Task {
                        await viewModel.startSelfDiscussion(
                            topic: topic,
                            turns: turns,
                            systemA: perspectiveA,
                            systemB: perspectiveB,
                            languageCodeA: languageA,
                            languageCodeB: languageB
                        )
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}
