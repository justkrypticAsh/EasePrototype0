// WatchContentView.swift
import SwiftUI
import WatchConnectivity

final class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isRecording: Bool = false
    @Published var consentCompleted: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var duration: String = "00:00"

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let rec = message["isRecording"] as? Bool {
                self.isRecording = rec
            }
            if let consent = message["consentCompleted"] as? Bool {
                self.consentCompleted = consent
            }
            if let dur = message["duration"] as? String {
                self.duration = dur
            }
        }
    }

    func toggleRecording() {
        guard WCSession.default.isReachable else {
            statusMessage = "iPhone unreachable"
            return
        }

        let command = isRecording ? "STOP_RECORDING" : "START_RECORDING"
        WCSession.default.sendMessage(["command": command]) { reply in
            DispatchQueue.main.async {
                if let status = reply["status"] as? String {
                    if status == "BLOCKED" {
                        self.statusMessage = reply["reason"] as? String ?? "Consent required on iPhone"
                    } else if status == "OK" {
                        self.isRecording = (reply["recording"] as? Bool) ?? false
                        self.statusMessage = self.isRecording ? "Recording active" : "Stopped"
                    }
                }
            }
        } errorHandler: { err in
            DispatchQueue.main.async {
                self.statusMessage = "Error: \(err.localizedDescription)"
            }
        }
    }
}

struct WatchContentView: View {
    @StateObject private var vm = WatchViewModel()

    var body: some View {
        VStack(spacing: 8) {
            Text("EASE Remote")
                .font(.headline)
                .foregroundColor(.cyan)

            if vm.isRecording {
                Text(vm.duration)
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text(vm.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Button {
                vm.toggleRecording()
            } label: {
                HStack {
                    Image(systemName: vm.isRecording ? "stop.fill" : "record.circle")
                    Text(vm.isRecording ? "Stop" : "Record")
                }
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(vm.isRecording ? Color.red : Color.cyan)
                .foregroundColor(.black)
                .cornerRadius(12)
            }

            Text("Audio recorded on iPhone")
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .padding()
    }
}
