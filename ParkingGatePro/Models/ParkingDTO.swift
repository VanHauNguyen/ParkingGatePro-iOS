//
//  ParkingDTO.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import Foundation

struct CheckInRequest: Encodable {
    let plateNo: String
    let gateId: Int
    let snapshotPath: String?
}

struct CheckInResponse: Decodable {
    let eventId: Int
    let sessionId: Int
    let plateNoRaw: String
    let plateNoNorm: String
    let monthlyFree: Bool
    let feeStatus: String
    let checkinTime: String
}

struct CheckOutRequest: Encodable {
    let plateNo: String
    let gateId: Int
    let snapshotPath: String?
}

struct CheckOutResponse: Decodable {
    let eventId: Int
    let sessionId: Int
    let plateNoRaw: String
    let plateNoNorm: String
    let checkinTime: String
    let checkoutTime: String
    let feeStatus: String
    let feeAmount: Int?
}
