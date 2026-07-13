//
//  ResetCreditsResponse.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct ResetCreditsResponse: Decodable {
    let availableCount: Int
    let credits: [ResetCredit]
}
