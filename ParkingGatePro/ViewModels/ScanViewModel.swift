//
//  ScanViewModel.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI


@MainActor
final class ScanViewModel: ObservableObject {

    // MARK: - Mode
    enum Mode: String, CaseIterable, Identifiable {
        case `in` = "IN"
        case out = "OUT"

        var id: String { rawValue }

        var endpoint: String {
            switch self {
            case .in:  return "/api/parking/in"
            case .out: return "/api/parking/out"
            }
        }

        var title: String {
            switch self {
            case .in:  return "Check-In"
            case .out: return "Check-Out"
            }
        }
    }

    // MARK: - Published state
    @Published var mode: Mode
    @Published var gateId: Int
    @Published var autoSubmit: Bool

    @Published var liveText: String = ""
    @Published var bestCandidate: String = ""
    @Published var bestScore: Int = 0
    @Published var isLoading: Bool = false

    // Results
    @Published var resultIn: CheckInResponse?
    @Published var resultOut: CheckOutResponse?

    // Error (TUYỆT ĐỐI KHÔNG DÙNG TÊN `error`)
    @Published var apiError: ParkingAPIError? = nil
    @Published var errorMessage: String? = nil

    // Sheet flags (nếu bạn có UI sheet)
    @Published var showResultSheet: Bool = false
    @Published var showErrorSheet: Bool = false

    @Published var result: ParkingAPIClient.ParkingInOutResponse?

    // MARK: - Private
    private var api: ParkingAPIClient
    private var lastSubmitAt: Date = .distantPast

    private var stableCandidate: String = ""
    private var stableCount: Int = 0
    
    // Majority vote buffer (giảm nhiễu OCR)
    private var recentCandidates: [String] = []
    private let maxRecent: Int = 10

    // MARK: - Init
    init(api: ParkingAPIClient, mode: Mode, gateId: Int, autoSubmit: Bool) {
        self.api = api
        self.mode = mode
        self.gateId = gateId
        self.autoSubmit = autoSubmit
    }

    func updateAPI(_ baseURL: URL) {
        self.api = ParkingAPIClient(baseURL: baseURL)
    }

    // MARK: - OCR input
    func onOCRText(_ text: String) {
        liveText = text

        guard let picked = PlateNormalizer.pickBest(from: text) else {
            bestCandidate = ""
            bestScore = 0
            stableCandidate = ""
            stableCount = 0
            return
        }

        let norm = PlateNormalizer.normalize(picked.candidate)
        bestCandidate = norm
        bestScore = picked.score

        //  Majority vote buffer
        recentCandidates.append(norm)
        if recentCandidates.count > maxRecent {
            recentCandidates.removeFirst(recentCandidates.count - maxRecent)
        }

        // chọn candidate xuất hiện nhiều nhất
        let freq = Dictionary(grouping: recentCandidates, by: { $0 }).mapValues { $0.count }
        let winner = freq.max(by: { $0.value < $1.value })?.key ?? norm
        let winCount = freq[winner] ?? 1

        // Auto submit khi winner đủ mạnh + throttle
        if autoSubmit,
           winCount >= 4,
           Date().timeIntervalSince(lastSubmitAt) > 1.2
        {
            Task { await submit(rawPlate: winner) }
        }

    }

    // MARK: - Submit
    @MainActor
    func submit(rawPlate: String) async {
        let raw = PlateNormalizer.normalize(rawPlate)
        guard !raw.isEmpty else {
            errorMessage = "Plate is empty."
            showErrorSheet = true
            return
        }

        lastSubmitAt = Date()   // ✅ THÊM Ở ĐÂY (fix throttle)

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .in:
                let res = try await api.checkIn(
                    plateNo: raw,
                    gateId: gateId,
                    snapshotPath: nil
                )
                result = res
                showResultSheet = true

            case .out:
                let res = try await api.checkOut(
                    plateNo: raw,
                    gateId: gateId,
                    snapshotPath: nil
                )
                result = res
                showResultSheet = true
            }
        } catch {
            print("❌ submit error:", error.localizedDescription)
            errorMessage = error.localizedDescription
            showErrorSheet = true
        }
    }


    // MARK: - Reset
    func reset() {
        liveText = ""
        bestCandidate = ""
        bestScore = 0
        recentCandidates.removeAll()
        
        resultIn = nil
        resultOut = nil

        apiError = nil
        errorMessage = nil

        showResultSheet = false
        showErrorSheet = false

        stableCandidate = ""
        stableCount = 0
        isLoading = false
    }
}
