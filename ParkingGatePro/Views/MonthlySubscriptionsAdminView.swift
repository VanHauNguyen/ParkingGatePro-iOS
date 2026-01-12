//
//  MonthlySubscriptionsAdminView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 11/1/26.
//

import SwiftUI

struct MonthlySubscriptionsAdminView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var vehicles: [ParkingAPIClient.VehicleDTO] = []
    @State private var selectedVehicleId: Int? = nil

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var planName: String = "月租"
    @State private var priceText: String = "400"

    @State private var activeToday: ParkingAPIClient.MonthlySubscriptionDTO? = nil
    @State private var subs: [ParkingAPIClient.MonthlySubscriptionDTO] = []

    @State private var isLoading = false
    @State private var errorText: String = ""

    // UI-only
    @State private var glow = false
    @State private var appear = false
    @State private var pressedRefresh = false
    @FocusState private var focusedField: Field?

    private enum Field { case planName, price }

    private var api: ParkingAPIClient { ParkingAPIClient(baseURL: settings.baseURL) }

    var body: some View {
        ZStack {
            GradientBackground()
                .overlay(auroraOverlay.opacity(0.70))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        vehiclePickerCard
                        activeCard
                        createCard
                        listCard
                        errorBanner
                        Spacer(minLength: 20)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 14)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                    .animation(.spring(response: 0.55, dampingFraction: 0.88), value: appear)
                }
                .refreshable { // UI-only
                    await refreshAll()
                }
            }
            .padding(.top, 14)

            // Overlay loading HUD nhưng không làm layout nhảy
            if isLoading {
                loadingHUD
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isLoading)
        .task { await loadVehicles() }
        .onAppear {
            appear = true
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glow.toggle() }
        }
        .toolbar {
            // tránh iOS tự animate keyboard toolbar làm layout nhảy (optional)
        }
    }

    // MARK: - VIP Background Overlay (UI only)

    private var auroraOverlay: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.25), Color.clear],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 420, height: 420)
                .blur(radius: 24)
                .offset(x: -120, y: -220)
                .opacity(glow ? 0.95 : 0.65)

            Circle()
                .fill(
                    LinearGradient(colors: [Color.purple.opacity(0.55), Color.pink.opacity(0.25), Color.clear],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 520, height: 520)
                .blur(radius: 28)
                .offset(x: 160, y: -180)
                .opacity(glow ? 0.85 : 0.55)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .blur(radius: 18)
                .offset(y: 280)
        }
        .allowsHitTesting(false)
    }

    // MARK: - TopBar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.lightTap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .shadow(radius: 12)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("月租管理")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("新增／取消月租車資格")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                Haptics.lightTap()
                Task { await refreshAll() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .shadow(radius: 12)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isLoading ? 180 : 0))
                        .animation(.easeInOut(duration: 0.35), value: isLoading)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .scaleEffect(pressedRefresh ? 0.96 : 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressedRefresh = true }
                    .onEnded { _ in pressedRefresh = false }
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Cards

    private var vehiclePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("選擇車輛")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                // small status pill (reserve size)
                HStack(spacing: 7) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(vehicles.isEmpty ? .yellow : .green)
                        .shadow(radius: 8)

                    Text(vehicles.isEmpty ? "載入中" : "\(vehicles.count) 台")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
            }

            Picker("車輛", selection: Binding(
                get: { selectedVehicleId ?? (vehicles.first?.id ?? 0) },
                set: { newValue in
                    selectedVehicleId = newValue
                    Haptics.lightTap()
                    Task { await refreshAll() }
                })
            ) {
                ForEach(vehicles) { v in
                    Text("#\(v.id) • \(v.plateNo)").tag(v.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("目前有效月租")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                statusBadgeForActive
            }

            ZStack(alignment: .leading) {
                // Content (reserve)
                VStack(alignment: .leading, spacing: 8) {
                    if let a = activeToday {
                        Text("編號 #\(a.id) • \(a.startDate) → \(a.endDate)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))

                        Text("\(a.planName) • \(a.price) • \(a.status)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))

                        Button {
                            Haptics.lightTap()
                            Task { await cancelActive(id: a.id) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                Text("取消月租")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.red.opacity(0.35))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("目前沒有有效月租。")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))

                        // reserve line to stabilize layout
                        Text(" ")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .opacity(0)
                    }
                }
                .opacity(isLoading ? 0 : 1)

                // Skeleton overlay (UI-only, no layout jump)
                VStack(alignment: .leading, spacing: 10) {
                    skeletonLine(width: 260)
                    skeletonLine(width: 220)
                    skeletonLine(width: 120)
                }
                .opacity(isLoading ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.18), value: isLoading)
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private var statusBadgeForActive: some View {
        let ok = (activeToday?.status.uppercased() == "ACTIVE")
        return Text(ok ? "有效" : "無")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(ok ? 1 : 0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(ok ? Color.green.opacity(0.30) : Color.white.opacity(0.10))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新增月租")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // Dates
            VStack(spacing: 10) {
                dateRow(title: "開始日期", date: $startDate, icon: "calendar")
                dateRow(title: "結束日期", date: $endDate, icon: "calendar.badge.clock")
            }

            // Plan / price
            HStack(spacing: 10) {
                vipTextField(title: "方案名稱", text: $planName, icon: "tag.fill", field: .planName)
                vipTextField(title: "金額", text: $priceText, icon: "dollarsign.circle.fill", field: .price, keyboard: .decimalPad)
                    .frame(width: 150)
            }

            Button {
                Haptics.lightTap()
                focusedField = nil
                Task { await createMonthly() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                    Text("建立月租")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.22)],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
                .shadow(radius: 16)
            }
            .buttonStyle(.plain)
            .disabled(selectedVehicleId == nil || isLoading)

            Text("※ 請選擇車輛（使用車輛編號），不是直接輸入車牌。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private func dateRow(title: String, date: Binding<Date>, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            DatePicker(title, selection: date, displayedComponents: .date)
                .tint(.white)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private func vipTextField(
        title: String,
        text: Binding<String>,
        icon: String,
        field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.80))
                .font(.system(size: 14, weight: .bold))

            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .focused($focusedField, equals: field)

            if !text.wrappedValue.isEmpty {
                Button {
                    Haptics.lightTap()
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("月租紀錄")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(subs.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                    .monospacedDigit()
            }

            ZStack(alignment: .topLeading) {
                // Content
                VStack(spacing: 10) {
                    if subs.isEmpty {
                        Text("目前沒有資料")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(subs) { s in
                            subRow(s)
                        }
                    }
                }
                .opacity(isLoading ? 0 : 1)

                // Skeleton
                VStack(alignment: .leading, spacing: 10) {
                    skeletonLine(width: 240)
                    skeletonLine(width: 200)
                    skeletonLine(width: 260)
                }
                .opacity(isLoading ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.18), value: isLoading)
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private func subRow(_ s: ParkingAPIClient.MonthlySubscriptionDTO) -> some View {
        let isActive = s.status.uppercased() == "ACTIVE"

        return HStack(alignment: .top, spacing: 12) {
            // Left accent
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.green.opacity(0.75) : Color.white.opacity(0.18))
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("#\(s.id)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("• \(s.status)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? Color.green.opacity(0.95) : Color.white.opacity(0.75))
                        .monospacedDigit()

                    Spacer()
                }

                Text("\(s.startDate) → \(s.endDate)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Text("\(s.planName) • \(s.price)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            if isActive {
                Button {
                    Haptics.lightTap()
                    Task { await cancelActive(id: s.id) }
                } label: {
                    Text("取消")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.35))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    // Fixed-height error area to prevent jumping
    private var errorBanner: some View {
        ZStack(alignment: .leading) {
            // Reserve 2 lines height always
            Text(" \n ")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .opacity(0)

            if !errorText.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.yellow.opacity(0.95))

                    Text(errorText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: errorText)
    }

    private var loadingHUD: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("處理中…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .shadow(radius: 18)
    }

    private func vipGlassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private func skeletonLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(width: width, height: 12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .redacted(reason: .placeholder)
            .shimmering(active: true)
    }

    // MARK: - Actions (GIỮ NGUYÊN LOGIC)

    @MainActor
    private func loadVehicles() async {
        isLoading = true
        defer { isLoading = false }

        errorText = ""
        do {
            vehicles = try await api.listVehicles()
            if selectedVehicleId == nil {
                selectedVehicleId = vehicles.first?.id
            }
            await refreshAll()
            Haptics.success()
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }

    @MainActor
    private func refreshAll() async {
        guard let vid = selectedVehicleId else { return }
        isLoading = true
        defer { isLoading = false }

        errorText = ""
        do {
            activeToday = try await api.getActiveMonthlyToday(vehicleId: vid)
            subs = try await api.listMonthly(vehicleId: vid)
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }

    @MainActor
    private func createMonthly() async {
        guard let vid = selectedVehicleId else { return }

        let start = Self.df.string(from: startDate)
        let end = Self.df.string(from: endDate)
        let price = Double(priceText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        isLoading = true
        defer { isLoading = false }
        errorText = ""

        do {
            _ = try await api.createMonthly(
                vehicleId: vid,
                startDate: start,
                endDate: end,
                planName: planName.isEmpty ? "月租" : planName,
                price: price
            )
            await refreshAll()
            Haptics.success()
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }

    @MainActor
    private func cancelActive(id: Int) async {
        isLoading = true
        defer { isLoading = false }
        errorText = ""

        do {
            _ = try await api.cancelMonthly(id: id)
            await refreshAll()
            Haptics.success()
        } catch {
            errorText = error.localizedDescription
            Haptics.error()
        }
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}


