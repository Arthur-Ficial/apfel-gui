// ============================================================================
// TTSManager.swift — On-device text-to-speech via AVSpeechSynthesizer
// Part of apfel GUI. Fully on-device, no internet needed.
// ============================================================================

import AVFoundation

@MainActor
class TTSManager: NSObject, AVSpeechSynthesizerDelegate, Observable {
    private static let preferredVoiceNames: [String: [String]] = [
        "en-US": ["Samantha", "Kathy", "Ralph", "Albert"],
        "en-GB": ["Daniel", "Eddy", "Flo"],
        "de-DE": ["Anna"],
        "fr-FR": ["Thomas"],
        "es-ES": ["Mónica"],
        "it-IT": ["Alice"],
        "pt-BR": ["Luciana"],
        "ja-JP": ["Kyoko"]
    ]

    struct VoiceOption: Identifiable, Hashable {
        let id: String
        let label: String
        let languageCode: String
    }

    static let preferredVoices: [VoiceOption] = [
        .init(id: "en-US", label: "English (US)", languageCode: "en-US"),
        .init(id: "en-GB", label: "English (UK)", languageCode: "en-GB"),
        .init(id: "de-DE", label: "German", languageCode: "de-DE"),
        .init(id: "fr-FR", label: "French", languageCode: "fr-FR"),
        .init(id: "es-ES", label: "Spanish", languageCode: "es-ES"),
        .init(id: "it-IT", label: "Italian", languageCode: "it-IT"),
        .init(id: "pt-BR", label: "Portuguese (BR)", languageCode: "pt-BR"),
        .init(id: "ja-JP", label: "Japanese", languageCode: "ja-JP")
    ]

    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak text aloud. Stops any current speech first.
    func speak(_ text: String, languageCode: String = "en-GB", voiceVariant: Int = 0) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        if let voice = bestVoice(for: languageCode, variant: voiceVariant) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Stop speaking immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    private func bestVoice(for languageCode: String, variant: Int) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == languageCode }
        let preferredNames = Self.preferredVoiceNames[languageCode] ?? []
        let ranked = voices.sorted { lhs, rhs in
            let lhsSiri = lhs.identifier.lowercased().contains("siri") || lhs.name.lowercased().contains("siri")
            let rhsSiri = rhs.identifier.lowercased().contains("siri") || rhs.name.lowercased().contains("siri")
            if lhsSiri != rhsSiri { return lhsSiri && !rhsSiri }
            let lhsPreferred = preferredNames.firstIndex(of: lhs.name) ?? Int.max
            let rhsPreferred = preferredNames.firstIndex(of: rhs.name) ?? Int.max
            if lhsPreferred != rhsPreferred { return lhsPreferred < rhsPreferred }
            let lhsModern = lhs.identifier.contains("com.apple.voice.")
            let rhsModern = rhs.identifier.contains("com.apple.voice.")
            if lhsModern != rhsModern { return lhsModern && !rhsModern }
            let lhsNovelty = lhs.identifier.contains("com.apple.speech.synthesis.voice.")
            let rhsNovelty = rhs.identifier.contains("com.apple.speech.synthesis.voice.")
            if lhsNovelty != rhsNovelty { return !lhsNovelty && rhsNovelty }
            let lhsEloquence = lhs.identifier.contains("eloquence")
            let rhsEloquence = rhs.identifier.contains("eloquence")
            if lhsEloquence != rhsEloquence { return !lhsEloquence && rhsEloquence }
            if lhs.quality.rawValue != rhs.quality.rawValue { return lhs.quality.rawValue > rhs.quality.rawValue }
            return lhs.name < rhs.name
        }
        if !ranked.isEmpty {
            return ranked[min(variant, ranked.count - 1)]
        }
        return AVSpeechSynthesisVoice(language: languageCode)
    }
}
