//
//  APIError.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import Foundation

struct APIErrorPayload: Decodable {
    let message: String?
    let error: String?
}

enum ParkingAPIError: Error, LocalizedError {
    case invalidURL
    case http(Int, String)
    case decodeFailed
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL."
        case .http(let code, let msg): return "[\(code)] \(msg)"
        case .decodeFailed: return "Response decode failed."
        case .network(let msg): return msg
        }
    }
}
