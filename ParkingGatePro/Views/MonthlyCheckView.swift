//
//  MonthlyCheckView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct MonthlyCheckView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var plateInput = ""
    @State private var isLoading = false
    @State private var result: ParkingAPIClient.CheckMonthlyResponse? = nil
    @State private var errMsg: String? = nil

    // UI only
    @FocusState private var plateFocused: Bool
    @State private var glow = false
    @State private var appear = false
    @State private var pressedCheck = false
    @State private var pressedClear = false

    private var normalized: String {
        PlateNormalizer.normalize(plateInput)
    }

    var body: some View {
        ZStack {
            GradientBackground()
                .overlay(auroraOverlay.opacity(0.70))
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    topBar

                    inputCard

                    quickActionsRow

                    actionButtons

                    resultCard

                    Spacer(minLength: 14)
                }
                .padding(.top, 14)
                .padding(.bottom, 16)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)
                .animation(.spring(response: 0.55, dampingFraction: 0.88), value: appear)
            }
            .refreshable { // UI only
                await check()
            }
        }
        .onAppear {
            plateInput = ""
            result = nil
            errMsg = nil

            appear = true
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glow.toggle()
            }
        }
    }

    // MARK: - VIP background overlay

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

    // MARK: - UI

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
                Text("月租查詢")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("月租狀態查詢 / Monthly Pass")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            statusPill
        }
        .padding(.horizontal, 16)
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(isLoading ? .yellow : (result == nil && errMsg == nil ? .gray : (errMsg == nil ? .green : .red)))
                .shadow(radius: 8)

            Text(isLoading ? "查詢中" : (result == nil && errMsg == nil ? "待查詢" : (errMsg == nil ? "完成" : "錯誤")))
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

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("車牌")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if !normalized.isEmpty {
                    Text("Normalized: \(normalized)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))

                    Image(systemName: "text.viewfinder")
                        .foregroundStyle(.white.opacity(0.85))
                        .font(.system(size: 18, weight: .bold))
                }

                TextField("例如：ABC-1234", text: $plateInput)
                    .focused($plateFocused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .submitLabel(.search)
                    .onSubmit {
                        Haptics.lightTap()
                        Task { await check() }
                    }

                if !plateInput.isEmpty {
                    Button {
                        Haptics.lightTap()
                        plateInput = ""
                        result = nil
                        errMsg = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.70))
                            .font(.system(size: 18, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Hint row (reserve height => tránh nhảy)
            ZStack(alignment: .leading) {
                Text("提示：支援輸入含 - 或空白，系統會自動格式化。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .opacity(plateFocused ? 0.95 : 0.85)

                // reserve area nếu muốn thay bằng warning / error inline sau này
                Text(" ")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0)
            }
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            quickChip(title: "貼上", icon: "doc.on.clipboard") {
                Haptics.lightTap()
                if let s = UIPasteboard.general.string {
                    plateInput = s
                    result = nil
                    errMsg = nil
                    plateFocused = true
                }
            }

            quickChip(title: "鍵盤", icon: "keyboard.chevron.compact.down") {
                Haptics.lightTap()
                plateFocused.toggle()
            }

            Spacer()

            quickChip(title: "清空結果", icon: "trash") {
                Haptics.lightTap()
                result = nil
                errMsg = nil
            }
        }
        .padding(.horizontal, 16)
    }

    private func quickChip(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 查詢
            Button {
                Haptics.lightTap()
                plateFocused = false
                Task { await check() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }

                    Text(isLoading ? "查詢中…" : "查詢")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.10)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
                .shadow(radius: 14)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || normalized.isEmpty)
            .scaleEffect(pressedCheck ? 0.98 : 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressedCheck = true }
                    .onEnded { _ in pressedCheck = false }
            )

            // 清除
            Button {
                Haptics.lightTap()
                plateInput = ""
                result = nil
                errMsg = nil
                plateFocused = true
            } label: {
                Text("清除")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.vertical, 13)
                    .frame(width: 110)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                    .shadow(radius: 12)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .scaleEffect(pressedClear ? 0.98 : 1)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressedClear = true }
                    .onEnded { _ in pressedClear = false }
            )
        }
        .padding(.horizontal, 16)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("查詢結果")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                // Always reserve space to avoid jump
                Text(result?.plate ?? (normalized.isEmpty ? "—" : normalized))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            ZStack(alignment: .leading) {
                if isLoading {
                    VStack(alignment: .leading, spacing: 10) {
                        skeletonLine(width: 180)
                        skeletonLine(width: 260)
                        skeletonLine(width: 220)
                    }
                    .transition(.opacity)
                } else {
                    contentResult
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.20), value: isLoading)
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 18)
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var contentResult: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errMsg {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red.opacity(0.95))
                    Text(errMsg)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.red.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let result {
                HStack(spacing: 10) {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(result.monthlyActive ? Color.green : Color.orange)
                        .shadow(radius: 8)

                    Text(result.monthlyActive ? "有效" : "無效")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    badge(result.monthlyActive ? "MONTHLY ACTIVE" : "NOT ACTIVE",
                          tint: result.monthlyActive ? .green : .orange)
                }

                Text(result.monthlyActive ? "此車牌目前有有效月租。" : "此車牌目前沒有有效月租。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("請輸入車牌後按「查詢」。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))

                    Text("小技巧：按鍵盤 Search 可直接查詢；下拉可重新查一次。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                }
            }
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.22))
                    .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
            )
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

    // MARK: - Action (LOGIC GIỮ NGUYÊN)

    @MainActor
    private func check() async {
        errMsg = nil
        result = nil
        guard !normalized.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)
        do {
            let r = try await api.checkMonthly(plate: normalized)
            result = r
            Haptics.success()
        } catch {
            errMsg = error.localizedDescription
            Haptics.error()
        }
    }
}


