//
//  ResetCredit.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ResetCredit: Decodable, Identifiable {
    let expiresAt: Date?
    let id: String
    let status: String
}
