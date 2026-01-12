//
//  ParkingResultSheet.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//


import SwiftUI

struct ParkingResultSheet: View {
    let title: String
    let modeLabel: String // "IN" / "OUT"
    let plate: String
    let gateId: Int
    let response: ParkingAPIClient.ParkingInOutResponse?

    let errorText: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 14) {
                header

                if let errorText {
                    errorCard(errorText)
                } else {
                    resultCard
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .padding(.top, 16)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(modeLabel) • 閘門 \(gateId)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("❌ 操作失敗")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(msg)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.red.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✅ 操作成功")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            gridRow("車牌", plate)
            gridRow("車牌（標準化）", response?.plateNoNorm ?? "-")
            gridRow("場次編號", response?.sessionId.map(String.init) ?? "-")
            gridRow("事件編號", response?.eventId.map(String.init) ?? "-")

            gridRow("月租免費", (response?.monthlyFree ?? false) ? "是" : "否")
            gridRow("費用狀態", response?.feeStatus ?? "-")
            gridRow("費用金額", money(response?.feeAmount))

            gridRow("入場時間", response?.checkinTime ?? "-")
            gridRow("出場時間", response?.checkoutTime ?? "-")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func gridRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 110, alignment: .leading)

            Text(v)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func money(_ v: Double?) -> String {
        guard let v else { return "-" }
        return String(format: "%.0f", v)
    }
}
