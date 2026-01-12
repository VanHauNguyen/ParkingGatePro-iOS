//
//  PlateNormalizer.swift
//  ParkingGatePro
//
//  Created by Hậu Nguyễn on 10/1/26.
//

import Foundation

enum PlateNormalizer {

    // MARK: - Normalizer (để các view khác dùng: VehicleEditSheet, VehiclesAdminView, search...)
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            // giữ lại chữ + số + '-' để phục vụ scoring trước khi cuối cùng normalize
            .replacingOccurrences(of: "[^A-Za-z0-9-]", with: "", options: .regularExpression)
            .uppercased()
    }

    // MARK: - Taiwan plate scoring patterns
    // Taiwan phổ biến:
    // - 新式汽車: ABC-1234
    // - 舊式汽車: AB-1234
    // - OCR hay bỏ dấu "-" -> ABC1234
    private static let patterns: [(NSRegularExpression, Int)] = {
        func r(_ p: String) -> NSRegularExpression {
            (try? NSRegularExpression(pattern: p, options: [.caseInsensitive]))!
        }
        return [
            (r(#"^[A-Z]{3}-?\d{4}$"#), 120),  // ABC-1234 / ABC1234
            (r(#"^[A-Z]{2}-?\d{4}$"#), 110),  // AB-1234 / AB1234
            (r(#"^[A-Z]{2}\d{5}$"#), 95),     // 可選：機車常見
            (r(#"^[A-Z0-9]{4,10}$"#), 40)     // fallback
        ]
    }()

    /// Pick best plate-like token from OCR raw text.
    /// - returns: (candidateNormalized, score)
    static func pickBest(from ocr: String) -> (candidate: String, score: Int)? {
        let raw = ocr.replacingOccurrences(of: "\n", with: " ")
        let tokens = raw
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        var best: (String, Int)? = nil

        for t in tokens {
            let cleaned = cleanupToken(t)
            let sc = scoreToken(cleaned)
            if sc > 0, (best == nil || sc > best!.1) {
                // ✅ Trả về dạng normalize cuối cùng: bỏ hết ký tự lạ và bỏ '-' cho consistent API
                best = (normalize(cleaned).replacingOccurrences(of: "-", with: ""), sc)
            }
        }

        return best
    }

    private static func cleanupToken(_ s: String) -> String {
        // giữ '-' nếu có; loại các ký tự lạ
        let u = s.uppercased()
        let allowed = u.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return String(allowed)
    }

    private static func scoreToken(_ s: String) -> Int {
        let u = s.uppercased()

        // length sanity (Taiwan car plate thường 6~7 ký tự chữ/số, tính không kể '-')
        let alnumCount = u.filter { $0.isLetter || $0.isNumber }.count
        if alnumCount < 4 || alnumCount > 8 { return 0 }

        // phải có cả chữ + số
        let hasLetter = u.contains(where: { $0.isLetter })
        let hasDigit  = u.contains(where: { $0.isNumber })
        guard hasLetter && hasDigit else { return 0 }

        var score = alnumCount

        // regex pattern scoring
        for (re, base) in patterns {
            let range = NSRange(location: 0, length: u.utf16.count)
            if re.firstMatch(in: u, options: [], range: range) != nil {
                score += base
                break
            }
        }

        // bonus nếu đúng kiểu có dấu '-'
        if u.contains("-") { score += 6 }

        // penalty nếu '-' sai vị trí (ví dụ A-BC1234)
        if u.contains("-") {
            let parts = u.split(separator: "-")
            if parts.count != 2 { score -= 10 }
        }

        return score
    }
}
