//
//  Haptics.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import UIKit

enum Haptics {
    static func lightTap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }
}
