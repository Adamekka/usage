//
//  ApplicationBandwidth.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import AppKit

struct ApplicationBandwidth: Identifiable {
    enum Identity: Hashable {
        case application(URL)
        case process(Int32)
    }

    let id: Identity
    let name: String
    let icon: NSImage?
    var download: Double
    var upload: Double
}
