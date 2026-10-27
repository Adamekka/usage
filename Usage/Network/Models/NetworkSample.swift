//
//  NetworkSample.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation

nonisolated struct NetworkSample {
    struct ProcessTraffic {
        let pid: Int32
        let name: String
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    let processes: [ProcessTraffic]
    let interval: TimeInterval

    init(processes: [ProcessTraffic], interval: TimeInterval) {
        precondition(interval > 0 && interval.isFinite, "A network sample needs a positive, finite interval")
        self.processes = processes
        self.interval = interval
    }
}
