import Foundation
import AVFoundation
import Combine

final class ReaderSpeechService: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var rate: Float = 0.46
    private var pitch: Float = 1.0
    private var volume: Float = 1.0

    override init() {
        super.init()
        synthesizer.delegate = self
        reloadSettings()
    }

    func reloadSettings() {
        let defaults = UserDefaults.standard
        let savedRate = defaults.double(forKey: ReaderSettingsKey.ttsRate)
        let savedPitch = defaults.double(forKey: ReaderSettingsKey.ttsPitch)
        let savedVolume = defaults.double(forKey: ReaderSettingsKey.ttsVolume)

        rate = Float(savedRate == 0 ? 0.46 : savedRate)
        pitch = Float(savedPitch == 0 ? 1.0 : savedPitch)
        volume = Float(savedVolume == 0 ? 1.0 : savedVolume)
    }

    func speak(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        stop()

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension ReaderSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
