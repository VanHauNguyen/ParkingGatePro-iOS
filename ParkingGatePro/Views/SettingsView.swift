//
//  SettingsView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    // Diagnostics
    @State private var isPinging = false
    @State private var serverOK: Bool? = nil
    @State private var pingMs: Int? = nil
    @State private var serverMsg: String = ""

    // Quick test
    @State private var testPlate: String = "ABC-1234"
    @State private var isTesting = false
    @State private var lastTestText: String = ""

    // UI
    @State private var showEditBaseURL = false
    @State private var showResetConfirm = false
    @State private var showExportToast = false

    private let msgReserveLines: Int = 2
    private let msgLineHeight: CGFloat = 16

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    topBar

                    serverCard

                    quickTestCard

                    defaultsCard

                    tipsCard

                    maintenanceCard

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
        }
        .onAppear { Task { await ping() } }
        .sheet(isPresented: $showEditBaseURL) {
            BaseURLEditSheet(
                current: settings.baseURLString,
                onSave: { newURL in
                    settings.baseURLString = newURL
                    Task { await ping() }
                }
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
        .confirmationDialog("重置設定", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("重置（Reset）", role: .destructive) {
                Haptics.lightTap()
                resetSettings()
            }
            Button("取消", role: .cancel) { Haptics.lightTap() }
        } message: {
            Text("將回復 Base URL / Gate / Auto Submit 的預設值。")
        }
        .overlay(alignment: .top) {
            if showExportToast {
                toastView(" 已複製診斷資訊到剪貼簿")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
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
                Text("工具 / 診斷")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("設定與快速測試")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button {
                Haptics.lightTap()
                Task { await ping() }
            } label: {
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
    }

    // MARK: - Cards

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("伺服器狀態", systemImage: "server.rack")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                statusPill
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Base URL")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))

                    Text(settings.baseURLString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    Haptics.lightTap()
                    showEditBaseURL = true
                } label: {
                    Label("編輯", systemImage: "pencil")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: CGFloat(msgReserveLines) * msgLineHeight)

                Text(serverMsg.isEmpty ? "點擊 Ping 測試連線（會顯示 Online / ms）" : serverMsg)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(msgReserveLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .transaction { tx in tx.animation = nil }
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.lightTap()
                    Task { await ping() }
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            ProgressView().tint(.white).opacity(isPinging ? 1 : 0)
                            Image(systemName: "dot.radiowaves.left.and.right").opacity(isPinging ? 0 : 1)
                        }
                        Text(isPinging ? "Ping 中…" : "Ping 伺服器")
                            .frame(width: 86, alignment: .leading)
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.lightTap()
                    UIPasteboard.general.string = settings.baseURLString
                    toast()
                } label: {
                    Label("複製 URL", systemImage: "doc.on.doc")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(16)
        .background(vipGlassCard(26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 20)
        .padding(.horizontal, 16)
    }

    private var quickTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("快速測試", systemImage: "bolt.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if isTesting { ProgressView().tint(.white) }
            }

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundStyle(.white.opacity(0.7))

                TextField("測試車牌（例：ABC-1234）", text: $testPlate)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)

                if !testPlate.isEmpty {
                    Button {
                        Haptics.lightTap()
                        testPlate = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))

            HStack(spacing: 10) {
                testButton(title: "測 IN", icon: "arrow.down.to.line", gradient: LinearGradient(colors: [.green, .teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                    await testIn()
                }

                testButton(title: "測 OUT", icon: "arrow.up.to.line", gradient: LinearGradient(colors: [.orange, .red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                    await testOut()
                }

                testButton(title: "查月票", icon: "calendar.badge.checkmark", gradient: LinearGradient(colors: [.cyan, .blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                    await testMonthly()
                }
            }

            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: CGFloat(3) * msgLineHeight)

                Text(lastTestText.isEmpty ? "提示：建議流程 Ping → IN → OUT → 月票" : lastTestText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .transaction { tx in tx.animation = nil }
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.lightTap()
                    UIPasteboard.general.string = lastTestText
                    toast()
                } label: {
                    Label("複製結果", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(lastTestText.isEmpty)

                Button {
                    Haptics.lightTap()
                    lastTestText = ""
                } label: {
                    Label("清除", systemImage: "trash")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(16)
        .background(vipGlassCard(26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 20)
        .padding(.horizontal, 16)
    }

    private var defaultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("常用設定", systemImage: "slider.horizontal.3")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                gateRow(title: "預設入口 Gate", value: $settings.defaultGateIn)
                gateRow(title: "預設出口 Gate", value: $settings.defaultGateOut)

                Toggle(isOn: $settings.autoSubmit) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自動送出（Auto Submit）")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                        Text("開啟後，掃描辨識到車牌會自動送出 IN/OUT")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .tint(.white)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(16)
        .background(vipGlassCard(26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 20)
        .padding(.horizontal, 16)
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("快速提示", systemImage: "sparkles")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            tipLine("建議流程：先 Ping 確認 Online → 再測 IN/OUT → 最後查月票。")
            tipLine("IN 成功會建立 OPEN session；同車牌重複 IN 可能回 409（已在場）。")
            tipLine("OUT 需要先有 OPEN session；沒有入場紀錄可能回 409（無可結束場次）。")
            tipLine("查月票 ACTIVE 代表有效；IN/OUT 回應可能出現 monthlyFree = true。")

            Divider().padding(.vertical, 4)

            Text("常見狀況")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))

            tipLine("Offline：Base URL 錯 / 網路不通 / 後端未啟動。")
            tipLine("500：後端例外（建議查看 server log）。")
            tipLine("409：多半是業務規則衝突（不一定是系統掛掉）。")
        }
        .padding(16)
        .background(vipGlassCard(26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 20)
        .padding(.horizontal, 16)
    }

    private var maintenanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("維護", systemImage: "wrench.and.screwdriver.fill")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                Button {
                    Haptics.lightTap()
                    exportDiagnostics()
                } label: {
                    Label("匯出診斷", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    Haptics.lightTap()
                    showResetConfirm = true
                } label: {
                    Label("重置設定", systemImage: "trash")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Text("匯出診斷會複製 JSON（含 Base URL / Gate / Auto Submit / Ping / 最後測試結果）到剪貼簿，方便貼到 LINE / Slack。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(16)
        .background(vipGlassCard(26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 20)
        .padding(.horizontal, 16)
    }

    // MARK: - Components

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .frame(width: 9, height: 9)
                .foregroundStyle(statusColor)
                .shadow(radius: 8)

            Text(statusText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: true, vertical: false)

            if let pingMs {
                Text("\(pingMs) ms")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func testButton(title: String, icon: String, gradient: LinearGradient, action: @escaping () async -> Void) -> some View {
        Button {
            Haptics.lightTap()
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
            .shadow(radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(isTesting || PlateNormalizer.normalize(testPlate).isEmpty)
        .opacity((isTesting || PlateNormalizer.normalize(testPlate).isEmpty) ? 0.6 : 1.0)
    }

    private func gateRow(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("G\(value.wrappedValue)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack(spacing: 10) {
                gateChip("1") { value.wrappedValue = 1 }
                gateChip("2") { value.wrappedValue = 2 }
                gateChip("3") { value.wrappedValue = 3 }
                gateChip("5") { value.wrappedValue = 5 }
                Spacer()
                Stepper("", value: value, in: 1...99)
                    .labelsHidden()
                    .tint(.white)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func gateChip(_ text: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.lightTap()
            action()
        } label: {
            Text("G\(text)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func tipLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .frame(width: 6, height: 6)
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func vipGlassCard(_ radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04),
                            Color.clear
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
    }

    private func toastView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    private func toast() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showExportToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) { showExportToast = false }
        }
    }

    // MARK: - UI helpers

    private var statusColor: Color {
        switch serverOK {
        case .some(true):  return .green
        case .some(false): return .red
        case .none:        return .yellow
        }
    }

    private var statusText: String {
        switch serverOK {
        case .some(true):  return "Online"
        case .some(false): return "Offline"
        case .none:        return "Unknown"
        }
    }

    // MARK: - Actions

    @MainActor
    private func ping() async {
        isPinging = true
        defer { isPinging = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)
        let start = Date()

        do {
            try await api.pingStatusOnly()
            pingMs = Int(Date().timeIntervalSince(start) * 1000.0)
            serverOK = true
            serverMsg = "可連線：\(settings.baseURLString)"
            Haptics.success()
        } catch {
            pingMs = nil
            serverOK = false
            serverMsg = error.localizedDescription
            Haptics.error()
        }
    }

    @MainActor
    private func testIn() async {
        await runTest {
            let api = ParkingAPIClient(baseURL: settings.baseURL)
            let p = PlateNormalizer.normalize(testPlate)
            let res = try await api.checkIn(plateNo: p, gateId: settings.defaultGateIn)
            return "✅ IN 成功：eventId=\(res.eventId ?? -1), sessionId=\(res.sessionId ?? -1), feeStatus=\(res.feeStatus ?? "-")"
        }
    }

    @MainActor
    private func testOut() async {
        await runTest {
            let api = ParkingAPIClient(baseURL: settings.baseURL)
            let p = PlateNormalizer.normalize(testPlate)
            let res = try await api.checkOut(plateNo: p, gateId: settings.defaultGateOut)
            return "✅ OUT 成功：eventId=\(res.eventId ?? -1), sessionId=\(res.sessionId ?? -1), fee=\(res.feeAmount ?? 0)"
        }
    }

    @MainActor
    private func testMonthly() async {
        await runTest {
            let api = ParkingAPIClient(baseURL: settings.baseURL)
            let p = PlateNormalizer.normalize(testPlate)
            let res = try await api.checkMonthly(plate: p)
            return "✅ 月票：\(res.monthlyActive ? "有效（ACTIVE）" : "無效（INACTIVE）")  plate=\(res.plate)"
        }
    }

    @MainActor
    private func runTest(_ block: @escaping () async throws -> String) async {
        lastTestText = ""
        isTesting = true
        defer { isTesting = false }

        do {
            lastTestText = try await block()
            Haptics.success()
        } catch {
            lastTestText = "❌ 失敗：\(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func exportDiagnostics() {
        let payload: [String: Any] = [
            "baseURL": settings.baseURLString,
            "defaultGateIn": settings.defaultGateIn,
            "defaultGateOut": settings.defaultGateOut,
            "autoSubmit": settings.autoSubmit,
            "serverOK": serverOK as Any,
            "pingMs": pingMs as Any,
            "serverMsg": serverMsg,
            "testPlate": PlateNormalizer.normalize(testPlate),
            "lastTestText": lastTestText,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let json: String
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let s = String(data: data, encoding: .utf8) {
            json = s
        } else {
            json = "\(payload)"
        }

        UIPasteboard.general.string = json
        toast()
    }

    private func resetSettings() {
        settings.baseURLString = "http://10.241.164.34:8080"
        settings.defaultGateIn = 1
        settings.defaultGateOut = 2
        settings.autoSubmit = true
        pingMs = nil
        serverOK = nil
        serverMsg = ""
        lastTestText = ""
        testPlate = "ABC-1234"
    }
}

// MARK: - Base URL Editor Sheet (VIP)

private struct BaseURLEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let current: String
    let onSave: (String) -> Void

    @State private var text: String = ""
    @State private var err: String? = nil

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 12) {
                HStack {
                    Text("編輯 Base URL")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text("例如：http://10.241.164.34:8080")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))

                    TextField("http://...", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    if let err {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.yellow.opacity(0.95))
                    }

                    HStack(spacing: 10) {
                        preset("本機") { text = "http://127.0.0.1:8080" }
                        preset("LAN") { text = current }
                        preset("清空") { text = "" }
                        Spacer()
                    }

                    Button {
                        Haptics.lightTap()
                        save()
                    } label: {
                        Text("儲存")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.14)))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 26).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(radius: 18)
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .onAppear { text = current }
    }

    private func preset(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.10)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            err = "Base URL 不能為空。"
            return
        }
        guard let url = URL(string: t),
              url.scheme?.hasPrefix("http") == true,
              url.host != nil else {
            err = "URL 格式不正確，請確認包含 http:// 或 https://"
            return
        }

        err = nil
        onSave(t)
        dismiss()
    }
}
