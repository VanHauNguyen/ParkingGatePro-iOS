//
//  Shimmer.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 12/1/26.
//

import SwiftUI

public extension View {
    func shimmering(active: Bool) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

public struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -0.7

    public func body(content: Content) -> some View {
        content.overlay {
            if active {
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.00),
                                    Color.white.opacity(0.16),
                                    Color.white.opacity(0.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(20))
                        .offset(x: geo.size.width * phase)
                        .blendMode(.plusLighter)
                        .mask(content)
                        .onAppear {
                            withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                                phase = 1.2
                            }
                        }
                }
            }
        }
    }
}
