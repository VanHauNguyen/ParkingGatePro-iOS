//
//  VehiclesListView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct VehiclesListView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errMsg: String? = nil
    @State private var vehicles: [ParkingAPIClient.VehicleDTO] = []
    @State private var search = ""

    // UI-only
    @State private var glow = false
    @State private var appear = false

    private var normalizedQuery: String {
        PlateNormalizer.normalize(search)
    }

    private var filtered: [ParkingAPIClient.VehicleDTO] {
        let q = normalizedQuery
        if q.isEmpty { return vehicles }
        return vehicles.filter { $0.plateNo.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        ZStack {
            GradientBackground()
                .overlay(auroraOverlay.opacity(0.70))
                .overlay(vignetteOverlay.opacity(0.30))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                searchCard

                if let errMsg {
                    errorBanner(errMsg)
                        .padding(.horizontal, 16)
                }

                statsRow

                contentBody
            }
            .padding(.top, 12)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 8)
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: appear)
        }
        .onAppear {
            appear = true
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glow.toggle() }
            Task { await reload() }
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("車輛清單")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("後端：\(settings.baseURLString)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                Haptics.lightTap()
                Task { await reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Search

    private var searchCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.75))

                TextField("搜尋車牌（例如：ABC-1234）", text: $search)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)

                if !search.isEmpty {
                    Button {
                        Haptics.lightTap()
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                miniPill(icon: "textformat", text: normalizedQuery.isEmpty ? "格式化：-" : "格式化：\(normalizedQuery)")
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if !normalizedQuery.isEmpty {
                    Button {
                        Haptics.lightTap()
                        search = ""
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eraser.fill")
                            Text("清除")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(vipGlassCard(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private func miniPill(icon: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill(icon: "square.stack.3d.up", title: "總筆數", value: "\(vehicles.count)")
            statPill(icon: "line.3.horizontal.decrease.circle", title: "顯示", value: "\(filtered.count)")
            if !normalizedQuery.isEmpty {
                statPill(icon: "magnifyingglass", title: "搜尋", value: normalizedQuery)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
    }

    private func statPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.85))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Content

    private var contentBody: some View {
        Group {
            if isLoading && vehicles.isEmpty {
                skeletonList
            } else if !isLoading && errMsg == nil && filtered.isEmpty {
                emptyState
            } else {
                vehiclesList
            }
        }
        .padding(.top, 2)
    }

    private var vehiclesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if isLoading {
                    // loading nhỏ phía trên khi refresh
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("載入中…")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.vertical, 8)
                }

                ForEach(filtered) { v in
                    vehicleCard(v)
                }

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .refreshable {
            await reload()
        }
    }

    private func vehicleCard(_ v: ParkingAPIClient.VehicleDTO) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 54, height: 54)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    Image(systemName: "car.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(v.plateNo)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        chip(icon: "number", text: "ID \(v.id)")
                        chip(icon: "clock", text: shortDate(v.createdAt))
                    }
                }

                Spacer()
            }

            Divider().overlay(Color.white.opacity(0.10))

            HStack {
                Text("API: /api/vehicles")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.60))
                Spacer()
                Text("createdAt")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func shortDate(_ createdAt: String) -> String {
        if createdAt.count >= 10 { return String(createdAt.prefix(10)) }
        return createdAt
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: vehicles.isEmpty ? "car.circle" : "magnifyingglass.circle")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))

            Text(vehicles.isEmpty ? "尚未建立車輛資料" : "找不到符合的結果")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(vehicles.isEmpty ? "目前沒有車牌資料可顯示。" : "請嘗試更換關鍵字再搜尋。")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                Haptics.lightTap()
                Task { await reload() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新載入")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 26)
        .padding(.horizontal, 16)
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 54, height: 54)
                    .shimmering(active: true)

                VStack(alignment: .leading, spacing: 10) {
                    skeletonLine(width: 180, height: 16)
                    skeletonLine(width: 220, height: 12)
                }

                Spacer()
            }

            skeletonLine(width: 260, height: 12)
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .redacted(reason: .placeholder)
            .shimmering(active: true)
    }

    // MARK: - Error banner

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)

            Spacer()

            Button {
                Haptics.lightTap()
                errMsg = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    // MARK: - Background helpers

    private var auroraOverlay: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.65), Color.blue.opacity(0.22), Color.clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 420)
                .blur(radius: 24)
                .offset(x: -130, y: -240)
                .opacity(glow ? 0.95 : 0.65)

            Circle()
                .fill(LinearGradient(colors: [Color.purple.opacity(0.50), Color.pink.opacity(0.22), Color.clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 520, height: 520)
                .blur(radius: 28)
                .offset(x: 160, y: -200)
                .opacity(glow ? 0.85 : 0.55)
        }
        .allowsHitTesting(false)
    }

    private var vignetteOverlay: some View {
        LinearGradient(colors: [Color.black.opacity(0.45), Color.clear, Color.black.opacity(0.30)],
                       startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }

    private func vipGlassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.04), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    // MARK: - API (GIỮ NGUYÊN)

    @MainActor
    private func reload() async {
        errMsg = nil
        isLoading = true
        defer { isLoading = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)
        do {
            vehicles = try await api.listVehicles()
        } catch {
            errMsg = error.localizedDescription
        }
    }
}

