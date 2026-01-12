//
//  AdminHubView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct AdminHubView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showVehicles = false
    @State private var showMonthlyAdmin = false
    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 12) {
                topBar

                VStack(spacing: 12) {
                    hubRow(
                        title: "車輛管理",
                        subtitle: "新增／修改／刪除車牌資料",
                        icon: "car.fill",
                        gradient: LinearGradient(
                            colors: [Color.gray, Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ) {
                        Haptics.lightTap()
                        showVehicles = true
                    }

                    hubRow(
                        title: "月租管理",
                        subtitle: "新增／取消月租車資格",
                        icon: "calendar.badge.plus",
                        gradient: LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    ) {
                        Haptics.lightTap()
                        showMonthlyAdmin = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 14)
        }
        .sheet(isPresented: $showVehicles) {
            VehiclesAdminView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showMonthlyAdmin) {
            MonthlySubscriptionsAdminView()
                .environmentObject(settings)
        }
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
                Text("後台管理")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(settings.baseURLString)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func hubRow(
        title: String,
        subtitle: String,
        icon: String,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(gradient)
                        .frame(width: 54, height: 54)
                        .shadow(radius: 14)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.55))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
            .shadow(radius: 16)
        }
        .buttonStyle(.plain)
    }
}
