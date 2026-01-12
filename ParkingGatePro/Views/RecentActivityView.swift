import SwiftUI

struct RecentActivityView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable { case sessions = "場次", events = "事件" }
    enum SessionFilter: String, CaseIterable {
        case all = "全部"
        case open = "進行中"
        case closed = "已結束"
    }

    @State private var sessionFilter: SessionFilter = .all

    @State private var tab: Tab = .sessions
    @State private var isLoading = false
    @State private var errMsg: String? = nil

    @State private var search = ""
    @State private var sessions: [ParkingAPIClient.SessionDTO] = []
    @State private var events: [ParkingAPIClient.EventDTO] = []
    @State private var vehiclesById: [Int: ParkingAPIClient.VehicleDTO] = [:]

    // UI-only
    @State private var glow = false
    @State private var appear = false

    var body: some View {
        ZStack {
            GradientBackground()
                .overlay(auroraOverlay.opacity(0.70))
                .overlay(vignetteOverlay.opacity(0.30))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                headerTools

                contentBody
            }
            .padding(.top, 12)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 8)
            .animation(.spring(response: 0.55, dampingFraction: 0.9), value: appear)
        }
        .onAppear {
            appear = true
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glow.toggle()
            }
            Task { await reloadAll() }
        }
        .refreshable {
            await reloadAll()
        }
        .onChange(of: tab) { t in
            if t == .events {
                sessionFilter = .all
            }

        }
    }

    // MARK: - Top

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
                Text("近期紀錄")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(settings.baseURLString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                Haptics.lightTap()
                Task { await reloadAll() }
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

    private var headerTools: some View {
        VStack(spacing: 12) {
            // Segmented tabs on glass
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .tint(.white)
            //  Session status filter (only for sessions tab)
            if tab == .sessions {
                Picker("", selection: $sessionFilter) {
                    ForEach(SessionFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .tint(.white)
            }

            // Search + stats
            VStack(spacing: 10) {
                searchBox

                HStack {
                    resultCountPill
                    Spacer()
                    quickHintPill
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.75))

            TextField("搜尋車牌／車輛編號／費用狀態", text: $search)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.white)

            if !search.isEmpty {
                Button {
                    Haptics.lightTap()
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(vipGlassCard(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var resultCountPill: some View {
        let count = (tab == .sessions) ? filteredSessions.count : filteredEvents.count
        return HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.white.opacity(0.85))

            Text("結果 \(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var quickHintPill: some View {
        HStack(spacing: 7) {
            Circle().frame(width: 6, height: 6).foregroundStyle(.white.opacity(0.7))
            Text(tab == .sessions ? "顯示最近 50 場次" : "顯示最近 50 事件")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Content

    private var contentBody: some View {
        Group {
            if isLoading {
                skeletonList
            } else if let errMsg {
                errorCard(errMsg)
            } else {
                listBody
            }
        }
        .padding(.top, 4)
    }

    private var listBody: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if tab == .sessions {
                    if filteredSessions.isEmpty {
                        emptyState(
                            title: "沒有符合的場次",
                            subtitle: "試試看搜尋車牌（如 ABC1234）或費用狀態（UNPAID / PAID）",
                            icon: "rectangle.stack.badge.person.crop"
                        )
                    } else {
                        ForEach(filteredSessions) { s in
                            sessionCard(s)
                        }
                    }
                } else {
                    if filteredEvents.isEmpty {
                        emptyState(
                            title: "沒有符合的事件",
                            subtitle: "試試看搜尋車牌（raw/norm）、狀態或事件類型（IN/OUT）",
                            icon: "bolt.badge.clock"
                        )
                    } else {
                        ForEach(filteredEvents) { e in
                            eventCard(e)
                        }
                    }
                }

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Cards

    private func sessionCard(_ s: ParkingAPIClient.SessionDTO) -> some View {
        let plate = vehiclesById[s.vehicleId]?.plateNo ?? "VID=\(s.vehicleId)"
        let statusText = s.isOpen ? "進行中" : (s.feeStatus ?? "-")
        let statusStyle = s.isOpen ? BadgeStyle(kind: .warning) : BadgeStyle(kind: (statusText.uppercased() == "PAID" ? .success : .neutral))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plate)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        miniChip(icon: "number", text: "SID \(s.id)")
                        miniChip(icon: "car", text: "VID \(s.vehicleId)")
                    }
                }

                Spacer()

                badge(statusText, style: statusStyle)
            }

            Divider().overlay(Color.white.opacity(0.10))

            HStack(spacing: 10) {
                timelinePill(
                    title: "入場",
                    value: s.checkinTime ?? "-",
                    icon: "arrow.right.circle.fill"
                )
                timelinePill(
                    title: "出場",
                    value: s.checkoutTime ?? "-",
                    icon: "arrow.left.circle.fill"
                )
            }

            HStack {
                Text("事件：IN \(s.checkinEventId ?? -1) / OUT \(s.checkoutEventId ?? -1)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                if let amt = s.feeAmount {
                    Text("費用 \(String(format: "%.0f", amt))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
    }

    private func eventCard(_ e: ParkingAPIClient.EventDTO) -> some View {
        let t = (e.eventType ?? "-").uppercased()
        let typeStyle: BadgeStyle = (t == "IN") ? .init(kind: .success) : (t == "OUT") ? .init(kind: .danger) : .init(kind: .neutral)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("#\(e.id)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .monospacedDigit()

                        badge(t, style: typeStyle)
                    }

                    Text(e.plateNoNorm ?? "-")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        miniChip(icon: "door.left.hand.open", text: "Gate \(e.gateId ?? -1)")
                        if let vid = e.vehicleId {
                            miniChip(icon: "car", text: "VID \(vid)")
                        }
                    }
                }

                Spacer()

                badge(e.status ?? "-", style: .init(kind: .neutral))
            }

            Divider().overlay(Color.white.opacity(0.10))

            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.white.opacity(0.7))
                Text(e.eventTime ?? "-")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .monospacedDigit()
                Spacer()
            }

            if let raw = e.plateNoRaw, !raw.isEmpty, raw != e.plateNoNorm {
                Text("Raw：\(raw)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
            }

            if let note = e.note, !note.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                    Text(note)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
    }

    // MARK: - Components

    private func badge(_ text: String, style: BadgeStyle) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(style.bg))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
    }

    private func miniChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
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

    private func timelinePill(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private func emptyState(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(14)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Button {
                Haptics.lightTap()
                Task { await reloadAll() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新載入")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.top, 8)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow.opacity(0.95))
                Text("載入失敗")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }

            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Button {
                Haptics.lightTap()
                Task { await reloadAll() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重試")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(16)
        .background(vipGlassCard(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(radius: 18)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Skeleton

    private var skeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonLine(width: 180, height: 16)
            skeletonLine(width: 120, height: 12)
            skeletonLine(width: 260, height: 12)
            skeletonLine(width: 210, height: 12)
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

    // MARK: - Filtering (GIỮ NGUYÊN LOGIC)

    private var filteredSessions: [ParkingAPIClient.SessionDTO] {
        //  1) filter by status first
        let base: [ParkingAPIClient.SessionDTO] = {
            switch sessionFilter {
            case .all: return sessions
            case .open: return sessions.filter { $0.isOpen }
            case .closed: return sessions.filter { !$0.isOpen }
            }
        }()

        //  2) then apply search
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return base }

        let qq = PlateNormalizer.normalize(q)

        return base.filter { s in
            let plate = vehiclesById[s.vehicleId]?.plateNo ?? ""
            if plate.contains(qq) { return true }
            if "\(s.vehicleId)".contains(q) { return true }
            if "\(s.id)".contains(q) { return true }
            if (s.feeStatus ?? "").localizedCaseInsensitiveContains(q) { return true }
            return false
        }
    }

    private var filteredEvents: [ParkingAPIClient.EventDTO] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return events }
        let qq = PlateNormalizer.normalize(q)

        return events.filter { e in
            if (e.plateNoNorm ?? "").contains(qq) { return true }
            if (e.plateNoRaw ?? "").localizedCaseInsensitiveContains(q) { return true }
            if (e.status ?? "").localizedCaseInsensitiveContains(q) { return true }
            if (e.eventType ?? "").localizedCaseInsensitiveContains(q) { return true }
            if let vid = e.vehicleId, "\(vid)".contains(q) { return true }
            return false
        }
    }

    // MARK: - Load (GIỮ NGUYÊN LOGIC)

    @MainActor
    private func reloadAll() async {
        errMsg = nil
        isLoading = true
        defer { isLoading = false }

        let api = ParkingAPIClient(baseURL: settings.baseURL)

        do {
            async let vTask = api.listVehicles()
            async let sTask = api.listRecentSessions(limit: 50)
            async let eTask = api.listRecentEvents(limit: 50)

            let v = try await vTask
            vehiclesById = Dictionary(uniqueKeysWithValues: v.map { ($0.id, $0) })

            sessions = try await sTask
            events = try await eTask
        } catch {
            errMsg = error.localizedDescription
        }
    }
}

// MARK: - Badge Style (UI only)

private struct BadgeStyle {
    enum Kind { case success, warning, danger, neutral }
    let kind: Kind

    var bg: Color {
        switch kind {
        case .success: return Color.green.opacity(0.35)
        case .warning: return Color.orange.opacity(0.35)
        case .danger:  return Color.red.opacity(0.35)
        case .neutral: return Color.white.opacity(0.12)
        }
    }
}

