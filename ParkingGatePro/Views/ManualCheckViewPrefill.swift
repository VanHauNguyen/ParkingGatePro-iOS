//
//  ManualCheckViewPrefill.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 11/1/26.
//

import SwiftUI

struct ManualCheckViewPrefill: View {
    let mode: ManualCheckView.Mode
    let initialPlate: String
    let initialGateId: Int

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ManualCheckView(mode: mode)
            .environmentObject(settings)
            .onAppear {
                // trick: nếu m muốn “real prefill” thì cần sửa ManualCheckView
                // thêm init param hoặc binding. Cách sạch nhất: nâng cấp ManualCheckView nhận initialPlate.
            }
    }
}
