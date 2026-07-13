//
//  RateLimit.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct RateLimit: Decodable {
    let primaryWindow: RateLimitWindow?
    let secondaryWindow: RateLimitWindow?
}
