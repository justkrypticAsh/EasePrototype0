// AudioPlayer.swift
import Foundation
import AVFoundation

final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func loadAudio(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0.0
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }

    func play() {
        guard let p = player else { return }
        p.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        guard let p = player else { return }
        p.currentTime = max(0, min(seconds, p.duration))
        currentTime = p.currentTime
        if !isPlaying {
            play()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let p = self.player else { return }
            self.currentTime = p.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopTimer()
        currentTime = 0.0
    }
}
