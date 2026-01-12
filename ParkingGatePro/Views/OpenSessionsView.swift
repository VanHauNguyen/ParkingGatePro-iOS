//
//  OpenSessionsView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//



import SwiftUI

struct OpenSessionsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errMsg: String? = nil
    @State private var sessions: [ParkingAPIClient.SessionDTO] = []
    @State private var vehiclesById: [Int: ParkingAPIClient.VehicleDTO] = [:]
    @State private var search = ""

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 12) {
                topBar
                searchBox

                if isLoading {
                    ProgressView("載入中…")
                        .tint(.white)
                        .padding(.top, 10)
                }

                if let errMsg {
                    Text(errMsg)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red.opacity(0.95))
                        .padding(.horizontal, 16)
                }

                List {
                    ForEach(filteredOpen) { s in
                        openRow(s)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear { Task { await reload() } }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("未出場車輛")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("查看仍在場內的車輛紀錄")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button { Task { await reload() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))
            TextField("搜尋車牌或車輛編號", text: $search)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var openOnly: [ParkingAPIClient.SessionDTO] {
        sessions.filter { $0.isOpen }
    }

    private var filteredOpen: [ParkingAPIClient.SessionDTO] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return openOnly }
        let qq = PlateNormalizer.normalize(q)

        return openOnly.filter { s in
            let plate = vehiclesById[s.vehicleId]?.plateNo ?? ""
            if plate.contains(qq) { return true }
            if "\(s.vehicleId)".contains(q) { return true }
            return false
        }
    }

    private func openRow(_ s: ParkingAPIClient.SessionDTO) -> some View {
        let plate = vehiclesById[s.vehicleId]?.plateNo ?? "車輛編號=\(s.vehicleId)"
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(plate)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Spacer()
                Text("未出場")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.92)))
            }
            Text("場次編號：\(s.id) • 入場事件編號：\(s.checkinEventId ?? -1)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text("入場時間：\(s.checkinTime ?? "-")")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 8)
    }

    @MainActor
    private func reload() async {
        errMsg = nil
        isLoading = true
        defer { isLoading = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)

        do {
            async let vTask = api.listVehicles()
            async let sTask = api.listRecentSessions(limit: 100)

            let v = try await vTask
            vehiclesById = Dictionary(uniqueKeysWithValues: v.map { ($0.id, $0) })

            sessions = try await sTask
        } catch {
            errMsg = error.localizedDescription
        }
    }
}
