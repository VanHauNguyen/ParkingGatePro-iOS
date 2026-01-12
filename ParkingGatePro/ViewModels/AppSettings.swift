//
//  AppSettings.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("baseURL") var baseURLString: String = "http://10.241.164.34:8080"
    @AppStorage("defaultGateIn") var defaultGateIn: Int = 1
    @AppStorage("defaultGateOut") var defaultGateOut: Int = 2
    @AppStorage("autoSubmit") var autoSubmit: Bool = true

    var baseURL: URL {
        URL(string: baseURLString) ?? URL(string: "http://10.241.164.34:8080")!
    }
}
