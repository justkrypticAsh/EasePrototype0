// APIClient.swift
import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case decodingError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .unauthorized: return "Session expired or unauthorized"
        case .serverError(let msg): return msg
        case .decodingError(let msg): return "Data parsing error: \(msg)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    // Configurable backend URL (defaults to localhost:8000 for simulator)
    var baseURLString = "http://127.0.0.1:8000/api/v1"

    private init() {}

    private var token: String? {
        KeychainHelper.shared.readString(key: "ease_access_token")
    }

    private func createRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURLString)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = self.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // Generic JSON Request
    func request<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        var req = try createRequest(path: path, method: method)
        req.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResp = response as? HTTPURLResponse else {
                throw APIError.serverError("Invalid server response")
            }

            if httpResp.statusCode == 401 {
                throw APIError.unauthorized
            }

            guard (200...299).contains(httpResp.statusCode) else {
                let errStr = String(data: data, encoding: .utf8) ?? "Server returned error \(httpResp.statusCode)"
                throw APIError.serverError(errStr)
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let err as APIError {
            throw err
        } catch let err as DecodingError {
            throw APIError.decodingError(err.localizedDescription)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // Multipart Meeting Upload
    func uploadMeeting(
        projectId: String,
        audioFileURL: URL,
        title: String,
        participants: [String],
        spokenAnnouncementPlayed: Bool
    ) async throws -> MeetingSummary {
        guard let url = URL(string: "\(baseURLString)/projects/\(projectId)/meetings/upload") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = self.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Form fields
        let fields: [String: String] = [
            "title": title,
            "participants": try String(data: JSONEncoder().encode(participants), encoding: .utf8) ?? "[]",
            "spoken_announcement_played": spokenAnnouncementPlayed ? "true" : "false",
            "all_consented": "true",
            "declined_participants": "[]"
        ]

        for (k, v) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(v)\r\n".data(using: .utf8)!)
        }

        // File part
        let audioData = try Data(contentsOf: audioFileURL)
        let filename = audioFileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw APIError.serverError(errStr)
        }

        return try JSONDecoder().decode(MeetingSummary.self, from: data)
    }
}
