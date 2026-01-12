//
//  ScanCameraView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI
import AVFoundation

struct ScanCameraView: View {
    enum Mode { case `in`, out }
    let mode: Mode

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var camera = CameraService()
    @StateObject private var vm: ScanViewModel

    // Keep single session
    @State private var captureSession: AVCaptureSession? = nil

    // Cache last plate
    @State private var lockedPlate: String = ""

    @State private var showResult = false
    @State private var resultResponse: ParkingAPIClient.ParkingInOutResponse? = nil
    @State private var resultError: String? = nil

    // Create confirm
    @State private var showCreateConfirm: Bool = false
    @State private var pendingPlateNorm: String = ""
    @State private var pendingGateId: Int = 1

    // UI-only
    @State private var glow = false
    @State private var isPaused = false
    @State private var showManual = false
    @State private var manualPrefill: String = ""
    @State private var freezeUI = false
    @State private var lastAcceptedPlate = ""
    @State private var lastOCRAt = Date.distantPast

    private let ocrThrottle: TimeInterval = 0.12   // 120ms
    private let resumeDelayNs: UInt64 = 3_000_000_000 // 3 giây

    private let liveReserveLines: Int = 2
    private let liveLineHeight: CGFloat = 16

    init(mode: Mode) {
        self.mode = mode
        // ✅ init bằng dummy api, sẽ update bằng settings.baseURL trong onAppear
        let dummy = ParkingAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!)
        let m: ScanViewModel.Mode = (mode == .in) ? .in : .out
        _vm = StateObject(wrappedValue: ScanViewModel(api: dummy, mode: m, gateId: 1, autoSubmit: true))
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 12) {
                topBar
                cameraPreview
                hudCard
                actionBar
                Spacer(minLength: 10)
            }
            .padding(.top, 14)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glow.toggle()
            }

            if captureSession == nil {
                captureSession = camera.makeSession()
            }

            // ✅ sync runtime settings
            syncSettings()

            camera.onText = { text in
                guard !isPaused, !showResult, !freezeUI else { return }

                let now = Date()
                guard now.timeIntervalSince(lastOCRAt) >= ocrThrottle else { return }
                lastOCRAt = now

                vm.onOCRText(text)
            }


            camera.start()
        }
        .onDisappear { camera.stop() }

        // foreground/background
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if !isPaused { camera.start() }
            } else {
                camera.stop()
            }
        }

        // settings changes
        .onChange(of: settings.baseURLString) { _ in syncSettings() }
        .onChange(of: settings.autoSubmit) { _ in syncSettings() }
        .onChange(of: settings.defaultGateIn) { _ in if mode == .in { vm.gateId = settings.defaultGateIn } }
        .onChange(of: settings.defaultGateOut) { _ in if mode == .out { vm.gateId = settings.defaultGateOut } }

        // bestCandidate -> lockedPlate
        .onChange(of: vm.bestCandidate) { v in
            let p = PlateNormalizer.normalize(v)
            if !p.isEmpty { lockedPlate = p }
        }

        // VM success -> result sheet
        .onChange(of: vm.showResultSheet) { show in
            guard show else { return }

            lastAcceptedPlate = PlateNormalizer.normalize(
                vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate
            )

            resultResponse = vm.result
            resultError = nil

            freezeUI = true
            isPaused = true
            camera.stop()

            showResult = true
            vm.showResultSheet = false
        }


        // VM error -> intercept vehicle not found
        .onChange(of: vm.showErrorSheet) { show in
            guard show else { return }

            let plate = PlateNormalizer.normalize(vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate)
            let err = vm.errorMessage ?? "未知錯誤"

            if isVehicleNotFoundMessage(err), !plate.isEmpty {
                pendingPlateNorm = plate
                pendingGateId = vm.gateId
                showCreateConfirm = true
                vm.showErrorSheet = false
                return
            }

            resultResponse = nil
            resultError = userFriendlyMessage(err)
            showResult = true
            vm.showErrorSheet = false
        }

        .sheet(isPresented: $showResult, onDismiss: {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: resumeDelayNs) // 3 giây

                freezeUI = false
                isPaused = false
                camera.start()
            }
        }) {
            ResultSheetSimpleView(
                title: mode == .in ? "掃描入場" : "掃描出場",
                modeLabel: mode == .in ? "IN" : "OUT",
                plate: lastAcceptedPlate.isEmpty
                    ? (vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate)
                    : lastAcceptedPlate,
                gateId: vm.gateId,
                response: resultResponse,
                errorText: resultError
            )
        }


        // ✅ nicer confirm UI
        .confirmationDialog("找不到車輛資料", isPresented: $showCreateConfirm, titleVisibility: .visible) {
            Button("建立並繼續") {
                Haptics.lightTap()
                Task { await createVehicleAndRetry() }
            }
            Button("改用手動輸入") {
                Haptics.lightTap()
                manualPrefill = pendingPlateNorm
                showManual = true
            }
            Button("取消", role: .cancel) {
                Haptics.lightTap()
                resultResponse = nil
                resultError = "此車牌尚未建立於系統中。您可以先建立車輛資料再繼續操作。"
                showResult = true
            }
        } message: {
            Text("車牌 \(pendingPlateNorm) 尚未建立於系統中。\n是否要先建立此車輛，然後繼續 \(mode == .in ? "入場" : "出場")？")
        }

        // ✅ open manual with prefill
        .sheet(isPresented: $showManual) {
            ManualCheckViewPrefill(
                mode: (mode == .in ? .in : .out),
                initialPlate: manualPrefill,
                initialGateId: vm.gateId
            )
            .environmentObject(settings)
        }
    }

    // MARK: - Sync

    @MainActor
    private func syncSettings() {
        vm.updateAPI(settings.baseURL)
        vm.autoSubmit = settings.autoSubmit
        vm.gateId = (mode == .in) ? settings.defaultGateIn : settings.defaultGateOut
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
                Text(mode == .in ? "掃描入場" : "掃描出場")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(settings.baseURLString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // pause/resume
            Button {
                Haptics.lightTap()
                isPaused.toggle()
                if isPaused { camera.stop() } else { camera.start() }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text(vm.autoSubmit ? "自動送出：開啟" : "自動送出：關閉")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Camera preview

    private var cameraPreview: some View {
        ZStack(alignment: .bottomLeading) {
            CameraView(session: captureSession ?? camera.makeSession())
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(reticleOverlay)
                .overlay(glowOverlay.opacity(glow ? 0.35 : 0.18))
                .overlay(
                    LinearGradient(colors: [Color.black.opacity(0.35), Color.clear],
                                   startPoint: .bottom, endPoint: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text(isPaused ? "已暫停辨識" : "請將鏡頭對準車牌")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("建議：保持距離、光線充足、避免反光")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .padding(.leading, 26)
            .padding(.bottom, 14)
        }
        .padding(.top, 4)
    }

    private var reticleOverlay: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(
                Color.white.opacity(0.60),
                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
            )
            .frame(width: 330, height: 118)
            .offset(y: 56)
            .shadow(radius: 10)
    }

    private var glowOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(colors: [
                    Color.cyan.opacity(0.45),
                    Color.purple.opacity(0.15),
                    Color.clear
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .blur(radius: 18)
    }

    // MARK: - HUD

    private var hudCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("辨識結果")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("G\(vm.gateId)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
            }

            HStack(spacing: 10) {
                Text("最佳車牌：")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))

                Text(bestPlateText)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer()

                Text("分數 \(vm.bestScore)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }

            ZStack(alignment: .topLeading) {
                Color.clear.frame(height: CGFloat(liveReserveLines) * liveLineHeight)

                Text(vm.liveText.isEmpty ? "等待 OCR…" : vm.liveText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(liveReserveLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .transaction { tx in tx.animation = nil }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 16)
        .padding(.horizontal, 16)
    }

    private var bestPlateText: String {
        let v = vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate
        return v.isEmpty ? "-" : v
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 10) {
            // Quick gates + Stepper
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    quickGate("預設", value: mode == .in ? settings.defaultGateIn : settings.defaultGateOut)
                    quickGate("G1", value: 1)
                    quickGate("G2", value: 2)
                    quickGate("G3", value: 3)
                    Spacer()
                }
                .padding(.horizontal, 16)

                Stepper(value: $vm.gateId, in: 1...99) {
                    Text("閘門 ID：\(vm.gateId)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .tint(.white)
                .padding(.horizontal, 16)
            }

            // Submit button
            Button {
                Haptics.lightTap()
                let plate = PlateNormalizer.normalize(vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate)
                Task { await vm.submit(rawPlate: plate) }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        ProgressView().tint(.white).opacity(vm.isLoading ? 1 : 0)
                        Image(systemName: mode == .in ? "arrow.down.to.line" : "arrow.up.to.line")
                            .font(.system(size: 15, weight: .bold))
                            .opacity(vm.isLoading ? 0 : 1)
                    }

                    Text(mode == .in ? "送出入場" : "送出出場")
                        .font(.system(size: 15, weight: .bold, design: .rounded))

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
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
                .shadow(radius: 18)
                .opacity(canSubmit ? 1.0 : 0.55)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)

            // Manual edit + open manual view
            HStack(spacing: 10) {
                Text("修正：")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                TextField("ABC-1234", text: Binding(
                    get: { vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate },
                    set: {
                        let p = PlateNormalizer.normalize($0)
                        vm.bestCandidate = p
                        if !p.isEmpty { lockedPlate = p }
                    }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))

                Button {
                    Haptics.lightTap()
                    manualPrefill = PlateNormalizer.normalize(vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate)
                    showManual = true
                } label: {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 2)
    }

    private var primaryGradient: LinearGradient {
        if mode == .in {
            return LinearGradient(colors: [Color.green, Color.teal, Color.cyan],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color.orange, Color.red, Color.pink],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var canSubmit: Bool {
        let plate = PlateNormalizer.normalize(vm.bestCandidate.isEmpty ? lockedPlate : vm.bestCandidate)
        return !vm.isLoading && !plate.isEmpty
    }

    private func quickGate(_ title: String, value: Int) -> some View {
        Button {
            Haptics.lightTap()
            vm.gateId = value
        } label: {
            Text(title == "預設" ? "預設 G\(value)" : title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(vm.gateId == value ? 0.95 : 0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(vm.gateId == value ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create + Retry

    @MainActor
    private func createVehicleAndRetry() async {
        let plate = pendingPlateNorm
        guard !plate.isEmpty else { return }

        vm.isLoading = true
        defer { vm.isLoading = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)

        do {
            _ = try await api.createVehicle(plateNo: plate)

            if mode == .in {
                let r = try await api.checkIn(plateNo: plate, gateId: pendingGateId)
                resultResponse = r
                resultError = "車輛資料不存在 → 已建立成功並完成處理。"
            } else {
                let r = try await api.checkOut(plateNo: plate, gateId: pendingGateId)
                resultResponse = r
                resultError = "車輛資料不存在 → 已建立成功並完成處理。"
            }
            showResult = true
        } catch {
            resultResponse = nil
            resultError = "建立/重試失敗：\(error.localizedDescription)"
            showResult = true
        }
    }

    // MARK: - Error mapping

    private func isVehicleNotFoundMessage(_ message: String) -> Bool {
        let s = message.lowercased()
        return s.contains("vehicle not found") || (s.contains("404") && s.contains("not found")) || s.contains("not found")
    }

    private func userFriendlyMessage(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("already checked in") ||
            (message.localizedCaseInsensitiveContains("open session") && message.localizedCaseInsensitiveContains("already")) {
            return "此車牌目前為「已入場」狀態。若要再次入場，請先完成出場。"
        }
        if message.localizedCaseInsensitiveContains("no open session") {
            return "目前沒有可出場的入場紀錄。請先完成入場。"
        }
        if message.localizedCaseInsensitiveContains("http 409") {
            return message.replacingOccurrences(of: "HTTP 409:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if message.localizedCaseInsensitiveContains("http 404") {
            return "查無資料（404）。請確認伺服器設定與車牌是否正確。"
        }
        return message
    }
}
