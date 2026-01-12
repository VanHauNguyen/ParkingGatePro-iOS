//
//  ResultSheetSimpleView.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct ResultSheetSimpleView: View {
    let title: String
    let modeLabel: String
    let plate: String
    let gateId: Int
    let response: ParkingAPIClient.ParkingInOutResponse?
    let errorText: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 14) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("完成") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                infoCard

                if let errorText, !errorText.isEmpty {
                    errorCard(errorText)
                } else if let response {
                    responseCard(response)
                } else {
                    emptyCard("沒有回應資料。")
                }

                Spacer(minLength: 10)
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(modeLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.15)))

                Text("車牌：\(plate)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text("閘門 \(gateId)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func responseCard(_ r: ParkingAPIClient.ParkingInOutResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            row("事件編號", r.eventId.map(String.init) ?? "-")
            row("場次編號", r.sessionId.map(String.init) ?? "-")
            row("車牌（原始）", r.plateNoRaw ?? "-")
            row("車牌（標準化）", r.plateNoNorm ?? "-")
            row("月租免費", r.monthlyFree.map { $0 ? "是" : "否" } ?? "-")
            row("費用狀態", r.feeStatus ?? "-")
            row("費用金額", r.feeAmount.map { String(format: "%.2f", $0) } ?? "-")
            row("入場時間", r.checkinTime ?? "-")
            row("出場時間", r.checkoutTime ?? "-")
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.9))
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("錯誤")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.red.opacity(0.20)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .padding(.horizontal, 16)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k + "：")
                .foregroundStyle(.white.opacity(0.65))
                .frame(width: 110, alignment: .leading)
            Text(v)
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
        }
    }
}
