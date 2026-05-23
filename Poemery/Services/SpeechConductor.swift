import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechConductor: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var lineQueue: [PoemLine] = []

    var highlightedLineID: PoemLine.ID?
    var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(poem: Poem, from lineIndex: Int) {
        stop()
        let safeIndex = poem.lines.indices.contains(lineIndex) ? lineIndex : 0
        lineQueue = Array(poem.lines[safeIndex...])
        speakNextLine()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        lineQueue.removeAll()
        highlightedLineID = nil
        isSpeaking = false
    }

    private func speakNextLine() {
        guard !lineQueue.isEmpty else {
            highlightedLineID = nil
            isSpeaking = false
            return
        }

        let line = lineQueue.removeFirst()
        highlightedLineID = line.id
        isSpeaking = true

        let utterance = AVSpeechUtterance(string: line.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 0.86
        utterance.volume = 0.92
        utterance.postUtteranceDelay = 0.42
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            speakNextLine()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            highlightedLineID = nil
            isSpeaking = false
        }
    }
}
