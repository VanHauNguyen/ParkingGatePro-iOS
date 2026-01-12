//
//  HomeDashboardView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI
import UIKit

struct HomeDashboardView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var showScanIn = false
    @State private var showScanOut = false
    @State private var showManualIn = false
    @State private var showManualOut = false
    @State private var showSettings = false

    @State private var showMonthlyCheck = false
    @State private var showRecentActivity = false
    @State private var showAdminHub = false
    @State private var showVehiclesList = false

    @State private var isPinging = false
    @State private var serverOK: Bool? = nil
    @State private var serverMsg: String = ""

    // UI-only
    @State private var glow = false
    @State private var pingMs: Int? = nil
    @State private var toastText: String? = nil

    private let serverMsgReserveLines: Int = 2
    private let serverMsgFont: Font = .system(size: 12, weight: .medium, design: .rounded)
    private let serverMsgLineHeight: CGFloat = 16

    var body: some View {
        ZStack {
            GradientBackground()
                .overlay(auroraOverlay.opacity(0.78))
                .overlay(vignetteOverlay.opacity(0.35))
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroHeader
                        .padding(.top, 14)

                    serverCard

                    sectionHeader(title: "閘門操作", subtitle: "掃描或手動輸入車牌以進行入場／出場")
                    gateActionsGrid

                    sectionHeader(title: "系統工具", subtitle: "使用資料庫／後端資源")
                    toolsList

//                    tipsCard

                    Spacer(minLength: 18)
                }
                .padding(.bottom, 18)
            }
            .refreshable { await pingServer() }
            
            if let toastText {
                toastView(toastText)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation(.easeInOut(duration: 0.2)) { self.toastText = nil }
                        }
                    }
            }
        }
        // sheets giữ nguyên
        .sheet(isPresented: $showScanIn) { ScanCameraView(mode: .in).environmentObject(settings) }
        .sheet(isPresented: $showScanOut) { ScanCameraView(mode: .out).environmentObject(settings) }
        .sheet(isPresented: $showManualIn) { ManualCheckView(mode: .in).environmentObject(settings) }
        .sheet(isPresented: $showManualOut) { ManualCheckView(mode: .out).environmentObject(settings) }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(settings) }
        .sheet(isPresented: $showMonthlyCheck) { MonthlyCheckView().environmentObject(settings) }
        .sheet(isPresented: $showRecentActivity) { RecentActivityView().environmentObject(settings) }
        .sheet(isPresented: $showAdminHub) { AdminHubView().environmentObject(settings) }
        .sheet(isPresented: $showVehiclesList) { VehiclesListView().environmentObject(settings) }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glow.toggle() }
            Task { await pingServer() }
        }
    }

    // MARK: - Hero Header (VIP)

    private var heroHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        .shadow(radius: 16)
                        .frame(width: 58, height: 58)

                    Image(systemName: "car.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color.white, Color.white.opacity(0.7)],
                                                       startPoint: .topLeading,
                                                       endPoint: .bottomTrailing))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("停車閘門專業版")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("OCR 掃描＋手動輸入＋入出場紀錄")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Button {
                    Haptics.lightTap()
                    showSettings = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                            .shadow(radius: 14)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Status + baseURL + chips
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    statusPill
                        .frame(minWidth: 72, alignment: .leading)

                    Text(settings.baseURLString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)

                    Button {
                        Haptics.lightTap()
                        copyToClipboard(settings.baseURLString)
                        toast("已複製 Base URL")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    chip("入場 G\(settings.defaultGateIn)")
                    chip("出場 G\(settings.defaultGateOut)")
                    chip(settings.autoSubmit ? "自動送出：開啟" : "自動送出：關閉")
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)

            // Quick Actions (Scan In/Out)
            HStack(spacing: 12) {
                quickActionPill(
                    title: "快速入場",
                    subtitle: "OCR 掃描",
                    icon: "viewfinder.circle.fill",
                    gradient: LinearGradient(colors: [Color.green, Color.teal, Color.cyan],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                ) { Haptics.lightTap(); showScanIn = true }

                quickActionPill(
                    title: "快速出場",
                    subtitle: "OCR 掃描",
                    icon: "viewfinder.circle",
                    gradient: LinearGradient(colors: [Color.orange, Color.red, Color.pink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                ) { Haptics.lightTap(); showScanOut = true }
            }
            .padding(.horizontal, 16)
        }
    }

    private func quickActionPill(
        title: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.14), Color.clear],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.16), lineWidth: 1))
            )
            .shadow(radius: 18)
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(statusColor)
                .shadow(radius: 10)

            Text(serverText)
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
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        )
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            )
    }

    // MARK: - Server card (NO JUMP + thêm latency)

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.white.opacity(0.92))
                        .font(.system(size: 16, weight: .bold))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.16), lineWidth: 1))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("伺服器狀態")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Ping / Health Check")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                Spacer()

                // latency badge
                latencyBadge

                Button {
                    Haptics.lightTap()
                    Task { await pingServer() }
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            ProgressView().tint(.white).opacity(isPinging ? 1 : 0)
                            Image(systemName: "bolt.horizontal.circle.fill").opacity(isPinging ? 0 : 1)
                        }
                        Text(isPinging ? "測試中" : "測試連線")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .leading)
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                statusDot

                VStack(alignment: .leading, spacing: 6) {
                    // Title — reserve height
                    ZStack(alignment: .leading) {
                        Text(serverTitleText)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .monospacedDigit()
                            .opacity(isPinging ? 0 : 1)

                        skeletonLine(width: 160)
                            .opacity(isPinging ? 1 : 0)
                    }
                    .frame(height: 18, alignment: .leading)

                    // Message — HARD reserve height
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(height: CGFloat(serverMsgReserveLines) * serverMsgLineHeight)

                        Text(effectiveServerMsg)
                            .font(serverMsgFont)
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(serverMsgReserveLines)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(isPinging ? 0 : 1)
                            .transaction { tx in tx.animation = nil }

                        VStack(alignment: .leading, spacing: 8) {
                            skeletonLine(width: 240)
                            skeletonLine(width: 200)
                        }
                        .opacity(isPinging ? 1 : 0)
                        .transaction { tx in tx.animation = nil }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(radius: 24)
        .padding(.horizontal, 16)
    }

    private var latencyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text("\(pingMs.map(String.init) ?? "—") ms")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.86))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.22))
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(statusColor.opacity(0.35), lineWidth: 1))
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(statusColor)
                .shadow(radius: 10)
        }
    }

    private var serverTitleText: String {
        serverText + (serverOK == .some(true) ? "（可用）" : serverOK == .some(false) ? "（不可用）" : "")
    }

    private var effectiveServerMsg: String {
        let fallback = "點擊右側按鈕測試連線，或確認 Base URL / LAN / 防火牆"
        return serverMsg.isEmpty ? fallback : serverMsg
    }

    private func skeletonLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(width: width, height: 12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .redacted(reason: .placeholder)
            .shimmering(active: true)
    }

    private var statusColor: Color {
        switch serverOK {
        case .some(true):  return .green
        case .some(false): return .red
        case .none:        return .yellow
        }
    }

    private var serverText: String {
        switch serverOK {
        case .some(true):  return "線上"
        case .some(false): return "離線"
        case .none:        return "未知"
        }
    }

    // MARK: - Gate actions grid

    private var gateActionsGrid: some View {
        VStack(spacing: 12) {
            actionRow(
                leftTitle: "掃描入場",
                leftSubtitle: "即時 OCR 相機辨識",
                leftIcon: "viewfinder.circle.fill",
                leftGradient: LinearGradient(colors: [Color.green, Color.teal, Color.cyan],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing),
                leftAction: { Haptics.lightTap(); showScanIn = true },

                rightTitle: "掃描出場",
                rightSubtitle: "即時 OCR 相機辨識",
                rightIcon: "viewfinder.circle",
                rightGradient: LinearGradient(colors: [Color.orange, Color.red, Color.pink],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing),
                rightAction: { Haptics.lightTap(); showScanOut = true }
            )

            actionRow(
                leftTitle: "手動入場",
                leftSubtitle: "手動輸入車牌",
                leftIcon: "keyboard.fill",
                leftGradient: LinearGradient(colors: [Color.green.opacity(0.95), Color.teal.opacity(0.95), Color.blue.opacity(0.8)],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing),
                leftAction: { Haptics.lightTap(); showManualIn = true },

                rightTitle: "手動出場",
                rightSubtitle: "手動輸入車牌",
                rightIcon: "keyboard",
                rightGradient: LinearGradient(colors: [Color.orange.opacity(0.95), Color.red.opacity(0.95), Color.purple.opacity(0.75)],
                                              startPoint: .topLeading,
                                              endPoint: .bottomTrailing),
                rightAction: { Haptics.lightTap(); showManualOut = true }
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tools list (VIP)

    private var toolsList: some View {
        VStack(spacing: 12) {
            toolRow(
                title: "月租查詢",
                subtitle: "確認是否為有效月租",
                icon: "calendar.badge.checkmark",
                gradient: LinearGradient(colors: [Color.cyan, Color.blue, Color.indigo],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                action: { Haptics.lightTap(); showMonthlyCheck = true }
            )

            toolRow(
                title: "近期紀錄",
                subtitle: "停車場次／事件時間軸",
                icon: "clock.arrow.circlepath",
                gradient: LinearGradient(colors: [Color.purple, Color.indigo, Color.blue],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                action: { Haptics.lightTap(); showRecentActivity = true }
            )

            toolRow(
                title: "管理後台（車輛與月租）",
                subtitle: "管理車輛／月租資料",
                icon: "person.badge.key.fill",
                gradient: LinearGradient(colors: [Color.gray, Color.black, Color.gray.opacity(0.9)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                action: { Haptics.lightTap(); showAdminHub = true }
            )

            toolRow(
                title: "車輛清單",
                subtitle: "查看已建立的車牌資料",
                icon: "car.2.fill",
                gradient: LinearGradient(colors: [Color.gray.opacity(0.85), Color.black, Color.blue.opacity(0.35)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                action: { Haptics.lightTap(); showVehiclesList = true }
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Section header

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 54, height: 6)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Tips (VIP chips)

//    private var tipsCard: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            HStack(spacing: 10) {
//                Image(systemName: "sparkles")
//                    .foregroundStyle(.white.opacity(0.9))
//                    .font(.system(size: 15, weight: .bold))
//                    .padding(9)
//                    .background(
//                        RoundedRectangle(cornerRadius: 14, style: .continuous)
//                            .fill(Color.white.opacity(0.10))
//                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.14), lineWidth: 1))
//                    )
//
//                Text("使用指南")
//                    .font(.system(size: 16, weight: .bold, design: .rounded))
//                    .foregroundStyle(.white)
//
//                Spacer()
//            }
//
//            tipLine("① 先看上方「伺服器狀態」：若顯示離線，請到「設定」確認 Base URL 是否正確、手機/電腦是否在同一個網段。")
//            tipLine("② 入場 / 出場：建議優先使用「掃描入場／掃描出場」（OCR），失敗再改用「手動入場／手動出場」。")
//            tipLine("③ 月租車：通行前可用「月租查詢」確認是否有效；有效月租通常不需付費。")
//            tipLine("④ 查紀錄：用「近期紀錄」看場次(Session)與事件(Event)，可用搜尋快速找車牌/狀態。")
//            tipLine("⑤ 管理功能：新增/修改車牌與月租請進「管理後台」，一般操作人員只需使用入/出場與查詢功能。")
//        }
//        .padding(16)
//        .background(vipGlassCard(cornerRadius: 26))
//        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
//        .shadow(radius: 22)
//        .padding(.horizontal, 16)
//        .padding(.top, 6)
//    }

    private func tipLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .frame(width: 6, height: 6)
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private func tipChip(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    // MARK: - Buttons (keep style, add press)

    private func actionRow(
        leftTitle: String,
        leftSubtitle: String,
        leftIcon: String,
        leftGradient: LinearGradient,
        leftAction: @escaping () -> Void,
        rightTitle: String,
        rightSubtitle: String,
        rightIcon: String,
        rightGradient: LinearGradient,
        rightAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            actionButton(title: leftTitle, subtitle: leftSubtitle, icon: leftIcon, gradient: leftGradient, action: leftAction)
            actionButton(title: rightTitle, subtitle: rightSubtitle, icon: rightIcon, gradient: rightGradient, action: rightAction)
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.22), lineWidth: 1))

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.65))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.14), Color.clear],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.16), lineWidth: 1))
            )
            .shadow(radius: 18)
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    private func toolRow(
        title: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(gradient)
                        .frame(width: 56, height: 56)
                        .shadow(radius: 16)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(16)
            .background(vipGlassCard(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(radius: 18)
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    // MARK: - Overlays

    private var auroraOverlay: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.70), Color.blue.opacity(0.25), Color.clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 420)
                .blur(radius: 24)
                .offset(x: -120, y: -230)
                .opacity(glow ? 0.95 : 0.65)

            Circle()
                .fill(LinearGradient(colors: [Color.purple.opacity(0.55), Color.pink.opacity(0.25), Color.clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 520, height: 520)
                .blur(radius: 28)
                .offset(x: 160, y: -190)
                .opacity(glow ? 0.85 : 0.55)
        }
        .allowsHitTesting(false)
    }

    private var vignetteOverlay: some View {
        LinearGradient(colors: [Color.black.opacity(0.45), Color.clear, Color.black.opacity(0.35)],
                       startPoint: .top,
                       endPoint: .bottom)
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

    // MARK: - Ping (logic giữ nguyên + đo ms)

    @MainActor
    private func pingServer() async {
        isPinging = true
        defer { isPinging = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)

        let start = CFAbsoluteTimeGetCurrent()
        do {
            try await api.pingStatusOnly()
            let end = CFAbsoluteTimeGetCurrent()
            pingMs = max(0, Int((end - start) * 1000.0))

            serverOK = true
            serverMsg = "連線成功：\(settings.baseURLString)"
            Haptics.success()
        } catch {
            let end = CFAbsoluteTimeGetCurrent()
            pingMs = max(0, Int((end - start) * 1000.0))

            serverOK = false
            serverMsg = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Toast + Clipboard

    private func toast(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) { toastText = text }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func toastView(_ text: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.95))
                Text(text)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
            .shadow(radius: 18)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Press effect

private struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

