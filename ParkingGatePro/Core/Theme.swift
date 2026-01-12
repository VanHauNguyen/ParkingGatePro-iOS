//
//  Theme.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import SwiftUI

enum Theme {
    static let corner: CGFloat = 20
    static let cardCorner: CGFloat = 24

    static let titleFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let subtitleFont: Font = .system(size: 15, weight: .medium, design: .rounded)

    static func shadow1() -> (Color, CGFloat, CGFloat, CGFloat) {
        (Color.black.opacity(0.18), 18, 0, 10)
    }

    static func shadow2() -> (Color, CGFloat, CGFloat, CGFloat) {
        (Color.black.opacity(0.25), 30, 0, 16)
    }
}
