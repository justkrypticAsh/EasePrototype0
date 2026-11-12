// AudioRecorder.swift
import Foundation
import AVFoundation
import Combine

final class AudioRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var meterLevel: Float = -160.0
    @Published var permissionGranted: Bool = false
    @Published var currentRecordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var timer: AnyCancellable?

    override init() {
        super.init()
        checkPermission()
        setupInterruptionListener()
    }

    func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissionGranted = true
        case .denied:
            permissionGranted = false
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                }
            }
        @unknown default:
            permissionGranted = false
        }
    }

    private func setupInterruptionListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began && isRecording {
            pauseRecording()
        } else if type == .ended {
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && isRecording {
                    audioRecorder?.record()
                }
            }
        }
    }

    func startRecording() -> Bool {
        guard permissionGranted else { return false }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
            return false
        }

        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = docDir.appendingPathComponent("EaseRec_\(UUID().uuidString).m4a")
        currentRecordingURL = audioFilename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            elapsedTime = 0.0

            timer = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                    self.elapsedTime += 0.1
                    recorder.updateMeters()
                    self.meterLevel = recorder.averagePower(forChannel: 0)
                }

            return true
        } catch {
            print("Failed to start audio recorder: \(error)")
            return false
        }
    }

    func pauseRecording() {
        audioRecorder?.pause()
    }

    func stopRecording() -> URL? {
        timer?.cancel()
        timer = nil
        audioRecorder?.stop()
        isRecording = false

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)

        return currentRecordingURL
    }

    var formattedDuration: String {
        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
