//
//  VehicleEditSheet.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

struct VehicleEditSheet: View {
    let title: String
    let initialPlate: String
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var plate: String = ""

    private var normalizedPlate: String {
        PlateNormalizer.normalize(plate)
    }

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 14) {
                topBar

                VStack(alignment: .leading, spacing: 10) {
                    Text("車牌號碼")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    TextField("ABC1234", text: $plate)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    Text("系統會自動格式化：移除符號並轉為大寫。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                Button {
                    Haptics.lightTap()
                    onSubmit(normalizedPlate)
                    dismiss()
                } label: {
                    Text("送出")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .disabled(normalizedPlate.isEmpty)
                .opacity(normalizedPlate.isEmpty ? 0.5 : 1.0)
            }
            .padding(.top, 12)
            .onAppear { plate = initialPlate }
        }
    }

    private var topBar: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                Haptics.lightTap()
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
        .padding(.top, 6)
    }
}
