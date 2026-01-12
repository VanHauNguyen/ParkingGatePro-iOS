//
//  ParkingAPIClient.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import Foundation

struct ParkingAPIClient {
    private(set) var baseURL: URL

    init(baseURL: URL) { self.baseURL = baseURL }
    mutating func updateBaseURL(_ url: URL) { self.baseURL = url }

    // MARK: - Models

    struct CheckMonthlyResponse: Decodable {
        let monthlyActive: Bool
        let plate: String
    }

    struct ParkingInOutResponse: Decodable {
        let eventId: Int?
        let sessionId: Int?
        let plateNoRaw: String?
        let plateNoNorm: String?
        let monthlyFree: Bool?
        let feeStatus: String?
        let feeAmount: Double?
        let checkinTime: String?
        let checkoutTime: String?
    }

    // Vehicles
    struct VehicleDTO: Decodable, Identifiable {
        let id: Int
        let plateNo: String
        let createdAt: String
    }

    // Recent Events
    struct EventDTO: Decodable, Identifiable {
        let id: Int
        let eventType: String?
        let eventTime: String?
        let gateId: Int?
        let vehicleId: Int?
        let plateNoRaw: String?
        let plateNoNorm: String?
        let ocrConfidence: Double?
        let snapshotPath: String?
        let status: String?
        let handledBy: Int?
        let note: String?
    }

    // Recent Sessions
    struct SessionDTO: Decodable, Identifiable {
        let id: Int
        let vehicleId: Int
        let checkinEventId: Int?
        let checkoutEventId: Int?
        let checkinTime: String?
        let checkoutTime: String?
        let feeAmount: Double?
        let feeStatus: String?
        let paidAt: String?

        var isOpen: Bool {
            // BE thường trả nil hoặc "" cho open
            let s = (checkoutTime ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty
        }
    }

    // Monthly
    struct MonthlyCreateRequest: Encodable {
        let vehicleId: Int
        let startDate: String // "yyyy-MM-dd"
        let endDate: String   // "yyyy-MM-dd"
        let planName: String
        let price: Double
    }

    struct MonthlyDTO: Decodable, Identifiable {
        let id: Int
        let vehicleId: Int
        let startDate: String?
        let endDate: String?
        let status: String?
        let planName: String?
        let price: Double?
        let createdAt: String?
    }

    struct MonthlyStatusRequest: Encodable {
        let status: String // "ACTIVE" | "SUSPENDED" | "EXPIRED"
    }

    // Errors
    struct APIErrorPayload: Decodable {
        let timestamp: String?
        let status: Int?
        let error: String?
        let message: String?
        let path: String?
    }

    enum APIError: LocalizedError {
        case invalidURL
        case http(status: Int, payload: APIErrorPayload?, rawBody: String)
        case decodeFailed(raw: String)
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .http(let status, let payload, let raw):
                if let msg = payload?.message, !msg.isEmpty { return "HTTP \(status): \(msg)" }
                if let err = payload?.error, !err.isEmpty { return "HTTP \(status): \(err)" }
                if !raw.isEmpty { return "HTTP \(status): \(raw)" }
                return "HTTP \(status)"
            case .decodeFailed(let raw):
                return "Decode failed. Raw: \(raw)"
            case .network(let e):
                return "Network error: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Public APIs

    /// GET /api/parking/check-monthly?plate=ABC-1234
    func checkMonthly(plate: String) async throws -> CheckMonthlyResponse {
        let p = PlateNormalizer.normalize(plate)

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/parking/check-monthly"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "plate", value: p)]
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        do {
            return try await perform(req, decodeAs: CheckMonthlyResponse.self)
        } catch let APIError.http(status, payload, raw) {
            let msg = (payload?.message ?? payload?.error ?? raw)
            if status == 404 || msg.localizedCaseInsensitiveContains("Vehicle not found") {
                return CheckMonthlyResponse(monthlyActive: false, plate: p)
            }
            throw APIError.http(status: status, payload: payload, rawBody: raw)
        }
    }

    /// POST /api/parking/in
    func checkIn(plateNo rawPlate: String, gateId: Int, snapshotPath: String? = nil) async throws -> ParkingInOutResponse {
        let plateNo = PlateNormalizer.normalize(rawPlate)
        let url = baseURL.appendingPathComponent("/api/parking/in")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["plateNo": plateNo, "gateId": gateId]
        if let snapshotPath { body["snapshotPath"] = snapshotPath }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        return try await perform(req, decodeAs: ParkingInOutResponse.self)
    }

    /// POST /api/parking/out
    func checkOut(plateNo rawPlate: String, gateId: Int, snapshotPath: String? = nil) async throws -> ParkingInOutResponse {
        let plateNo = PlateNormalizer.normalize(rawPlate)
        let url = baseURL.appendingPathComponent("/api/parking/out")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["plateNo": plateNo, "gateId": gateId]
        if let snapshotPath { body["snapshotPath"] = snapshotPath }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        return try await perform(req, decodeAs: ParkingInOutResponse.self)
    }

    /// GET /api/vehicles
    func listVehicles() async throws -> [VehicleDTO] {
        let url = baseURL.appendingPathComponent("/api/vehicles")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await perform(req, decodeAs: [VehicleDTO].self)
    }

    /// GET /api/parking/events/recent?limit=50
    func listRecentEvents(limit: Int = 50) async throws -> [EventDTO] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/parking/events/recent"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = comps?.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await perform(req, decodeAs: [EventDTO].self)
    }

    /// GET /api/parking/sessions/recent?limit=50
    func listRecentSessions(limit: Int = 50) async throws -> [SessionDTO] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/parking/sessions/recent"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = comps?.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await perform(req, decodeAs: [SessionDTO].self)
    }

    // MARK: - Vehicles Admin CRUD

    func createVehicle(plateNo: String) async throws -> VehicleDTO {
        let url = baseURL.appendingPathComponent("/api/vehicles")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["plateNo": PlateNormalizer.normalize(plateNo)]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return try await perform(req, decodeAs: VehicleDTO.self)
    }

    func updateVehicle(id: Int, plateNo: String) async throws -> VehicleDTO {
        let url = baseURL.appendingPathComponent("/api/vehicles/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["plateNo": PlateNormalizer.normalize(plateNo)]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return try await perform(req, decodeAs: VehicleDTO.self)
    }

    func deleteVehicle(id: Int) async throws {
        let url = baseURL.appendingPathComponent("/api/vehicles/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try await perform(req, decodeAs: EmptyResponse.self)
    }

    // MARK: - Monthly Subscriptions

    /// POST /api/monthly-subscriptions
    func createMonthly(_ reqBody: MonthlyCreateRequest) async throws -> MonthlyDTO {
        let url = baseURL.appendingPathComponent("/api/monthly-subscriptions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(reqBody)
        return try await perform(req, decodeAs: MonthlyDTO.self)
    }

    /// GET /api/monthly-subscriptions?vehicleId=3
    func listMonthlyByVehicle(vehicleId: Int) async throws -> [MonthlyDTO] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/monthly-subscriptions"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "vehicleId", value: "\(vehicleId)")]
        guard let url = comps?.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        // BE đôi khi trả object nếu chỉ 1 phần tử (PowerShell in vậy)
        // -> decode array trước, fail thì decode single rồi wrap.
        do {
            return try await perform(req, decodeAs: [MonthlyDTO].self)
        } catch {
            let one: MonthlyDTO = try await perform(req, decodeAs: MonthlyDTO.self)
            return [one]
        }
    }

    /// GET /api/monthly-subscriptions/active?vehicleId=3
    func getActiveMonthlyToday(vehicleId: Int) async throws -> MonthlyDTO {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/monthly-subscriptions/active"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "vehicleId", value: "\(vehicleId)")]
        guard let url = comps?.url else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await perform(req, decodeAs: MonthlyDTO.self)
    }

    /// (Nếu backend có) PUT /api/monthly-subscriptions/{id}/extend?days=30
    func extendMonthly(id: Int, days: Int) async throws -> MonthlyDTO {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/monthly-subscriptions/\(id)/extend"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "days", value: "\(days)")]
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        return try await perform(req, decodeAs: MonthlyDTO.self)
    }

    /// (Nếu backend có) PUT /api/monthly-subscriptions/{id}/status
    func updateMonthlyStatus(id: Int, status: String) async throws -> MonthlyDTO {
        let url = baseURL.appendingPathComponent("/api/monthly-subscriptions/\(id)/status")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(MonthlyStatusRequest(status: status))
        return try await perform(req, decodeAs: MonthlyDTO.self)
    }

    // MARK: - Ping

    func pingStatusOnly() async throws {
        let url = baseURL.appendingPathComponent("/api/vehicles")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        logRequest(req)

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            print(" [API] status:", http.statusCode)
            guard (200...299).contains(http.statusCode) else {
                throw APIError.http(status: http.statusCode, payload: nil, rawBody: "")
            }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network(error)
        }
    }

    // MARK: - Core performer

    private func perform<T: Decodable>(_ req: URLRequest, decodeAs type: T.Type) async throws -> T {
        logRequest(req)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

            let raw = String(data: data, encoding: .utf8) ?? ""
            logResponse(status: http.statusCode, raw: raw)

            guard (200...299).contains(http.statusCode) else {
                let payload = try? JSONDecoder().decode(APIErrorPayload.self, from: data)
                throw APIError.http(status: http.statusCode, payload: payload, rawBody: raw)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decodeFailed(raw: raw)
            }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network(error)
        }
    }

    // MARK: - Logging helpers

    private func logRequest(_ req: URLRequest) {
        print("➡️ [API] \(req.httpMethod ?? "") \(req.url?.absoluteString ?? "")")
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty { print("   headers:", headers) }
        if let body = req.httpBody, let s = String(data: body, encoding: .utf8) { print("   body:", s) }
    }

    private func logResponse(status: Int, raw: String) {
        print(" [API] status:", status)
        print("   raw:", raw)
    }

    struct EmptyResponse: Decodable {}
}
// MARK: - Monthly Subscriptions Admin

extension ParkingAPIClient {

    struct MonthlySubscriptionDTO: Decodable, Identifiable {
        let id: Int
        let vehicleId: Int
        let startDate: String
        let endDate: String
        let status: String
        let planName: String
        let price: Double
    }

    private struct MonthlyCreateBody: Encodable {
        let vehicleId: Int
        let startDate: String   // yyyy-MM-dd
        let endDate: String     // yyyy-MM-dd
        let planName: String
        let price: Double
    }

    /// POST /api/monthly-subscriptions
    func createMonthly(vehicleId: Int, startDate: String, endDate: String, planName: String, price: Double) async throws -> MonthlySubscriptionDTO {
        let url = baseURL.appendingPathComponent("/api/monthly-subscriptions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = MonthlyCreateBody(vehicleId: vehicleId, startDate: startDate, endDate: endDate, planName: planName, price: price)
        req.httpBody = try JSONEncoder().encode(body)

        return try await perform(req, decodeAs: MonthlySubscriptionDTO.self)
    }

    /// GET /api/monthly-subscriptions?vehicleId=3
    func listMonthly(vehicleId: Int) async throws -> [MonthlySubscriptionDTO] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/monthly-subscriptions"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "vehicleId", value: "\(vehicleId)")]
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await perform(req, decodeAs: [MonthlySubscriptionDTO].self)
    }

    /// GET /api/monthly-subscriptions/active?vehicleId=3
    /// - Nếu không có active -> backend trả 404 -> mình trả nil để UI hiển thị "không có"
    func getActiveMonthlyToday(vehicleId: Int) async throws -> MonthlySubscriptionDTO? {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/api/monthly-subscriptions/active"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "vehicleId", value: "\(vehicleId)")]
        guard let url = comps?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        do {
            return try await perform(req, decodeAs: MonthlySubscriptionDTO.self)
        } catch let APIError.http(status, _, _) where status == 404 {
            return nil
        }
    }

    /// PUT /api/monthly-subscriptions/{id}/cancel
    func cancelMonthly(id: Int) async throws -> MonthlySubscriptionDTO {
        let url = baseURL.appendingPathComponent("/api/monthly-subscriptions/\(id)/cancel")
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        return try await perform(req, decodeAs: MonthlySubscriptionDTO.self)
    }
}
extension ParkingAPIClient {
    /// detect "vehicle not found" from various backend styles (404, 500, payload message, raw)
    func isVehicleNotFound(_ error: Error) -> Bool {
        guard let e = error as? APIError else { return false }
        switch e {
        case .http(_, let payload, let raw):
            let msg = (payload?.message ?? payload?.error ?? raw).lowercased()
            return msg.contains("vehicle not found") || msg.contains("not found")
        default:
            return false
        }
    }
}
