
//
//  ManualCheckView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct ManualCheckView: View {
    enum Mode { case `in`, out }
    let mode: Mode

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var plateText: String = ""
    @State private var gateId: Int = 1
    @State private var isSubmitting: Bool = false

    // Result sheet
    @State private var showResult: Bool = false
    @State private var lastResponse: ParkingAPIClient.ParkingInOutResponse? = nil
    @State private var lastErrorText: String? = nil

    // Confirm before create
    @State private var showCreateConfirm: Bool = false
    @State private var pendingPlateNorm: String = ""
    @State private var pendingGateId: Int = 1

    // UI-only
    @State private var appear = false
    @FocusState private var plateFocused: Bool

    private let hintReserveLines: Int = 2
    private let hintLineHeight: CGFloat = 16

    private var normalizedPlate: String {
        PlateNormalizer.normalize(plateText)
    }

    private var titleText: String { mode == .in ? "手動入場" : "手動出場" }
    private var modeLabel: String { mode == .in ? "入場" : "出場" }

    private var primaryGradient: LinearGradient {
        if mode == .in {
            return LinearGradient(colors: [Color.green, Color.teal, Color.cyan],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color.orange, Color.red, Color.pink],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        ZStack {
            GradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    topBar

                    statusCard

                    inputCard

                    submitButton

                    Spacer(minLength: 10)
                }
                .padding(.top, 14)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
                .animation(.spring(response: 0.55, dampingFraction: 0.88), value: appear)
            }
            .scrollDismissesKeyboard(.interactively)

            if isSubmitting {
                loadingOverlay
            }
        }
        .onAppear {
            gateId = (mode == .in) ? settings.defaultGateIn : settings.defaultGateOut
            appear = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                plateFocused = true
            }
        }
        .sheet(isPresented: $showResult) {
            ResultSheetSimpleView(
                title: titleText,
                modeLabel: modeLabel,
                plate: normalizedPlate,
                gateId: gateId,
                response: lastResponse,
                errorText: lastErrorText
            )
        }
        // ✅ dùng confirmationDialog (đẹp + iOS style hơn alert)
        .confirmationDialog(
            "找不到此車牌",
            isPresented: $showCreateConfirm,
            titleVisibility: .visible
        ) {
            Button("建立車輛並繼續") {
                Haptics.lightTap()
                Task { await createVehicleAndRetry() }
            }
            Button("取消", role: .cancel) {
                Haptics.lightTap()
                lastResponse = nil
                lastErrorText = "此車牌尚未建立。您可以先建立車輛資料再繼續操作。"
                showResult = true
            }
        } message: {
            Text("車牌 \(pendingPlateNorm) 尚未建立。\n是否要先新增此車牌，然後繼續\(mode == .in ? "入場" : "出場")？")
        }
    }

    // MARK: - Top bar

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
                Text(titleText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(settings.baseURLString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // quick help: clear + focus
            Button {
                Haptics.lightTap()
                plateText = ""
                lastResponse = nil
                lastErrorText = nil
                plateFocused = true
            } label: {
                Image(systemName: "eraser.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Status / Guide card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: mode == .in ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("操作模式：\(modeLabel)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("輸入車牌 → 選擇閘門 → 送出")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                // Gate pill
                Text("G\(gateId)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }

            // reserve height for small hint (avoid jump)
            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: CGFloat(hintReserveLines) * hintLineHeight)

                Text(hintText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(hintReserveLines)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
    }

    private var hintText: String {
        if normalizedPlate.isEmpty {
            return "提示：支援輸入 ABC-1234 / ABC1234；系統會自動格式化。"
        }
        return "格式化：\(normalizedPlate)（確認無誤再送出）"
    }

    // MARK: - Input card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("車牌號碼")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if !plateText.isEmpty {
                    Button {
                        Haptics.lightTap()
                        plateText = ""
                        plateFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(.white.opacity(0.75))

                TextField("例如：ABC-1234", text: $plateText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($plateFocused)
                    .foregroundStyle(.white)
                    .onSubmit { Task { await submit() } }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
            )

            gatePicker

            // quick gates
            quickGateRow
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var gatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("閘門")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.80))

            Stepper(value: $gateId, in: 1...99) {
                Text("閘門編號：\(gateId)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .monospacedDigit()
            }
            .tint(.white)
        }
    }

    private var quickGateRow: some View {
        HStack(spacing: 10) {
            gateChip("預設", value: mode == .in ? settings.defaultGateIn : settings.defaultGateOut)
            gateChip("G1", value: 1)
            gateChip("G2", value: 2)
            gateChip("G3", value: 3)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func gateChip(_ title: String, value: Int) -> some View {
        Button {
            Haptics.lightTap()
            gateId = value
        } label: {
            HStack(spacing: 6) {
                if title == "預設" {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title == "預設" ? "預設 G\(value)" : title)
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(gateId == value ? 0.95 : 0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(gateId == value ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Haptics.lightTap()
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    ProgressView().tint(.white).opacity(isSubmitting ? 1 : 0)
                    Image(systemName: mode == .in ? "arrow.down.to.line" : "arrow.up.to.line")
                        .font(.system(size: 15, weight: .bold))
                        .opacity(isSubmitting ? 0 : 1)
                }

                Text(isSubmitting ? "送出中…" : (mode == .in ? "送出入場" : "送出出場"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(primaryGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .shadow(radius: 18)
            .opacity(canSubmit ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        !isSubmitting && !normalizedPlate.isEmpty
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("處理中…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Submit flow with confirm-create (LOGIC GIỮ NGUYÊN)

    @MainActor
    private func submit() async {
        let p = PlateNormalizer.normalize(plateText)
        guard !p.isEmpty else { return }

        plateFocused = false

        isSubmitting = true
        defer { isSubmitting = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)

        do {
            if mode == .in {
                lastResponse = try await api.checkIn(plateNo: p, gateId: gateId)
            } else {
                lastResponse = try await api.checkOut(plateNo: p, gateId: gateId)
            }
            lastErrorText = nil
            showResult = true
        } catch {
            if isVehicleNotFound(error) {
                pendingPlateNorm = p
                pendingGateId = gateId
                showCreateConfirm = true
                return
            }

            lastResponse = nil
            lastErrorText = userFriendlyMessage(error)
            showResult = true
        }
    }

    @MainActor
    private func createVehicleAndRetry() async {
        let p = pendingPlateNorm
        guard !p.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)

        do {
            _ = try await api.createVehicle(plateNo: p)

            if mode == .in {
                lastResponse = try await api.checkIn(plateNo: p, gateId: pendingGateId)
            } else {
                lastResponse = try await api.checkOut(plateNo: p, gateId: pendingGateId)
            }

            lastErrorText = "此車牌原本未建立 → 已成功新增。"
            showResult = true
        } catch {
            lastResponse = nil
            lastErrorText = "建立／重試失敗：\(userFriendlyMessage(error))"
            showResult = true
        }
    }

    // MARK: - Error helpers (GIỮ NGUYÊN + chút bền hơn)

    private func isVehicleNotFound(_ error: Error) -> Bool {
        if let apiErr = error as? ParkingAPIClient.APIError {
            switch apiErr {
            case .http(_, let payload, let rawBody):
                let msg = (payload?.message ?? payload?.error ?? rawBody).lowercased()
                if msg.contains("vehicle not found") { return true }
                if msg.contains("not found") && msg.contains("vehicle") { return true }
                // 404 也可能是 vehicle not found
                if msg.contains("404") && (msg.contains("vehicle") || msg.contains("not found")) { return true }
                return false
            default:
                return false
            }
        }
        let s = error.localizedDescription.lowercased()
        return s.contains("vehicle not found") || s.contains("http 404")
    }

    private func userFriendlyMessage(_ error: Error) -> String {
        let text = error.localizedDescription

        if text.localizedCaseInsensitiveContains("already checked in") ||
            (text.localizedCaseInsensitiveContains("open session") && text.localizedCaseInsensitiveContains("already")) {
            return "此車牌目前已在場內（已入場）。如需重新入場，請先完成出場。"
        }

        if text.localizedCaseInsensitiveContains("no open session") {
            return "找不到可出場的紀錄。請先完成入場操作。"
        }

        if text.localizedCaseInsensitiveContains("http 409") {
            return text
                .replacingOccurrences(of: "HTTP 409:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.localizedCaseInsensitiveContains("http 404") {
            return "找不到資料（404）。請確認伺服器設定或車牌輸入是否正確。"
        }

        return text
    }

    // MARK: - Shared glass card

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
}
