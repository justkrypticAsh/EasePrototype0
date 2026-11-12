// WatchSessionManager.swift
import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var isWatchConnected: Bool = false
    @Published var remoteRecordingRequested: Bool = false
    @Published var remoteStopRequested: Bool = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isPaired && session.isWatchAppInstalled
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let command = message["command"] as? String {
                switch command {
                case "START_RECORDING":
                    // STRICT: Can only start if consent is completed on phone
                    let consentReady = UserDefaults.standard.bool(forKey: "ease_consent_ready")
                    if consentReady {
                        self.remoteRecordingRequested = true
                        replyHandler(["status": "OK", "recording": true])
                    } else {
                        replyHandler(["status": "BLOCKED", "reason": "Consent must be completed on iPhone first."])
                    }
                case "STOP_RECORDING":
                    self.remoteStopRequested = true
                    replyHandler(["status": "OK", "recording": false])
                default:
                    replyHandler(["status": "UNKNOWN"])
                }
            }
        }
    }

    func sendStateToWatch(isRecording: Bool, consentCompleted: Bool, duration: String) {
        guard WCSession.default.isReachable else { return }
        let payload: [String: Any] = [
            "isRecording": isRecording,
            "consentCompleted": consentCompleted,
            "duration": duration
        ]
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
}
