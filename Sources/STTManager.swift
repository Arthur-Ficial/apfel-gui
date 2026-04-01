// ============================================================================
// STTManager.swift — On-device speech-to-text via SFSpeechRecognizer
// Part of apfel GUI. On-device transcription when available.
// ============================================================================

import Speech
import AVFoundation
import AppKit

@Observable
@MainActor
class STTManager {
    enum SettingsTarget {
        case microphone
        case speechRecognition
        case dictation
    }

    var isListening = false
    var transcript = ""
    var errorMessage: String?
    var shouldOfferOpenSettings = false
    private var settingsTarget: SettingsTarget?

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var userStoppedSession = false

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Check if speech recognition is available and authorized.
    var isAvailable: Bool {
        guard let recognizer else { return false }
        return recognizer.isAvailable && SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Request microphone and speech recognition permissions.
    func requestPermissions() async -> Bool {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .authorized:
            break
        case .denied, .restricted:
            errorMessage = "Microphone denied. Enable in System Settings → Privacy & Security → Microphone."
            shouldOfferOpenSettings = true
            settingsTarget = .microphone
            printStderr("STT: microphone authorization denied (status: \(micStatus.rawValue))")
            return false
        case .notDetermined:
            let micAuthorized = await withUnsafeContinuation { (continuation: UnsafeContinuation<Bool, Never>) in
                let handler: @Sendable (Bool) -> Void = { granted in
                    continuation.resume(returning: granted)
                }
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: handler)
            }

            if !micAuthorized {
                errorMessage = "Microphone not authorized. Enable in System Settings → Privacy & Security → Microphone."
                shouldOfferOpenSettings = true
                settingsTarget = .microphone
                printStderr("STT: microphone authorization denied after request")
                return false
            }
            printStderr("STT: microphone authorized")
        @unknown default:
            errorMessage = "Unknown microphone authorization status"
            printStderr("STT: unknown microphone authorization status: \(micStatus.rawValue)")
            return false
        }

        // Check current status first — avoid the callback entirely if already decided
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        if currentStatus == .authorized {
            printStderr("STT: already authorized")
            return true
        }
        if currentStatus == .denied || currentStatus == .restricted {
            errorMessage = "Speech recognition denied. Enable in System Settings → Privacy & Security → Speech Recognition."
            shouldOfferOpenSettings = true
            settingsTarget = .speechRecognition
            printStderr("STT: authorization denied (status: \(currentStatus.rawValue))")
            return false
        }

        // Status is .notDetermined — need to request
        // SFSpeechRecognizer calls back off-main, so keep the continuation handler sendable.
        let authorized = await withUnsafeContinuation { (continuation: UnsafeContinuation<Bool, Never>) in
            let handler: @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void = { status in
                continuation.resume(returning: status == .authorized)
            }
            SFSpeechRecognizer.requestAuthorization(handler)
        }

        if !authorized {
            errorMessage = "Speech recognition not authorized. Enable in System Settings → Privacy & Security → Speech Recognition."
            shouldOfferOpenSettings = true
            settingsTarget = .speechRecognition
            printStderr("STT: authorization denied after request")
        } else {
            printStderr("STT: authorized")
        }
        return authorized
    }

    /// Start listening to microphone and transcribing.
    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available for this language"
            printStderr("STT: recognizer not available")
            return
        }

        transcript = ""
        clearErrorState()
        userStoppedSession = false

        do {
            let engine = AVAudioEngine()
            self.audioEngine = engine

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            // Prefer on-device recognition if available
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
                printStderr("STT: using on-device recognition")
            } else {
                printStderr("STT: on-device not available, using server")
            }

            self.recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if !self.transcript.isEmpty {
                            self.clearErrorState()
                        }
                    }
                    if let error {
                        printStderr("STT: recognition error: \(error.localizedDescription)")
                        if self.shouldIgnore(error: error) {
                            self.clearErrorState()
                        } else if self.transcript.isEmpty {
                            self.errorMessage = self.message(for: error)
                        }
                        self.cleanup()
                    }
                }
            }

            // Install audio tap
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                errorMessage = "No microphone input available"
                printStderr("STT: invalid audio format (no mic?)")
                return
            }

            nonisolated(unsafe) let audioRequest = request
            let tapHandler: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
                audioRequest.append(buffer)
            }
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat, block: tapHandler)

            engine.prepare()
            try engine.start()
            isListening = true
            printStderr("STT: listening started")

        } catch {
            errorMessage = "Failed to start listening: \(error.localizedDescription)"
            printStderr("STT: start error: \(error)")
            cleanup()
        }
    }

    /// Stop listening and return the final transcript.
    func stopListening() -> String {
        printStderr("STT: stopping, transcript: \"\(transcript)\"")
        userStoppedSession = true
        cleanup()
        return transcript
    }

    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    private func clearErrorState() {
        errorMessage = nil
        shouldOfferOpenSettings = false
        settingsTarget = nil
    }

    private func shouldIgnore(error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        if userStoppedSession {
            return true
        }
        if message.contains("cancel") || message.contains("no speech detected") {
            return true
        }
        return false
    }

    private func message(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("siri and dictation are disabled") || message.contains("dictation") {
            shouldOfferOpenSettings = true
            settingsTarget = .dictation
            return "Speech recognition is disabled. Enable Siri or Dictation in System Settings, then try the microphone again."
        }
        shouldOfferOpenSettings = false
        settingsTarget = nil
        return "Speech recognition failed: \(error.localizedDescription)"
    }

    func openSystemSettings() {
        let urlString: String
        switch settingsTarget {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .speechRecognition:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        case .dictation:
            urlString = "x-apple.systempreferences:com.apple.preference.speech?Dictation"
        case nil:
            urlString = "x-apple.systempreferences:com.apple.preference.security"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}
