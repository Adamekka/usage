//
//  CodexTokens.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

struct CodexTokens: Decodable {
    let accessToken: String
    let accountID: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accountID = "account_id"
    }
}
