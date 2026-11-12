// SpeechSynthesizerService.swift
import Foundation
import AVFoundation

final class SpeechSynthesizerService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechSynthesizerService()

    @Published var isSpeaking: Bool = false
    @Published var currentText: String = ""

    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, language: String = "en-US", rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0

        currentText = text
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentText = ""
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentText = ""
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentText = ""
        }
    }
}
