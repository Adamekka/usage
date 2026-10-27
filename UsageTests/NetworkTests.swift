//
//  NetworkTests.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import Foundation
import Testing
@testable import Usage

@MainActor
struct NetworkTests {
    @Test
    func `lifetime counters are discarded and live samples use the measured interval`() throws {
        let start: ContinuousClock.Instant = .now
        let samples: [NetworkSample] = try NetworkMonitor.samplesForTesting([
            (",bytes_in,bytes_out,", start),
            ("Example.42,900000000,800000000,", start),
            (",bytes_in,bytes_out,", start.advanced(by: .milliseconds(1250))),
            ("Example.42,2500,1250,", start.advanced(by: .milliseconds(1250))),
            (",bytes_in,bytes_out,", start.advanced(by: .milliseconds(2500))),
        ])

        let sample: NetworkSample = try #require(samples.first)
        let traffic: NetworkSample.ProcessTraffic = try #require(sample.processes.first)
        #expect(samples.count == 1)
        #expect(sample.interval == 1.25)
        #expect(traffic.bytesIn == 2500)
        #expect(traffic.bytesOut == 1250)
        #expect(Double(traffic.bytesIn) / sample.interval == 2000)
        #expect(Double(traffic.bytesOut) / sample.interval == 1000)
    }

    @Test
    func `process labels preserve commas and use the last dot for the PID`() throws {
        let start: ContinuousClock.Instant = .now
        let samples: [NetworkSample] = try NetworkMonitor.samplesForTesting([
            (",bytes_in,bytes_out,", start),
            (",bytes_in,bytes_out,", start.advanced(by: .seconds(1))),
            ("App, Helper.v2.123,4096,512,", start.advanced(by: .seconds(1))),
            (",bytes_in,bytes_out,", start.advanced(by: .seconds(2))),
        ])

        let traffic: NetworkSample.ProcessTraffic = try #require(samples.first?.processes.first)
        #expect(traffic.pid == 123)
        #expect(traffic.name == "App, Helper.v2")
    }

    @Test
    func `idle samples clear processes from the previous interval`() throws {
        let start: ContinuousClock.Instant = .now
        let samples: [NetworkSample] = try NetworkMonitor.samplesForTesting([
            (",bytes_in,bytes_out,", start),
            (",bytes_in,bytes_out,", start.advanced(by: .seconds(1))),
            ("Example.42,1024,0,", start.advanced(by: .seconds(1))),
            (",bytes_in,bytes_out,", start.advanced(by: .seconds(2))),
            (",bytes_in,bytes_out,", start.advanced(by: .seconds(3))),
        ])

        #expect(samples.count == 2)
        #expect(samples[0].processes.count == 1)
        #expect(samples[1].processes.isEmpty)
    }

    @Test(arguments: [
        "Example.no-pid,1,2,",
        "Example.0,1,2,",
        "Example.42,invalid,2,",
        "Example.42,1,2",
        "nettop: permission denied",
    ])
    func `malformed traffic is an explicit failure`(line: String) {
        let start: ContinuousClock.Instant = .now
        #expect(throws: NetworkMonitor.Failure.self) {
            try NetworkMonitor.samplesForTesting([
                (",bytes_in,bytes_out,", start),
                (line, start),
            ])
        }
    }

    @Test
    func `traffic without a header is an explicit failure`() {
        #expect(throws: NetworkMonitor.Failure.self) {
            try NetworkMonitor.samplesForTesting([("Example.42,1,2,", .now)])
        }
    }

    @Test
    func `nested helper bundles belong to the outer application`() {
        let outer: URL = .init(filePath: "/Applications/Example.app", directoryHint: .isDirectory)
        let helper: URL = outer.appending(path: "Contents/Frameworks/Example Helper.app/Contents/MacOS/Example Helper")

        #expect(NetworkStore.applicationURLForTesting(for: helper) == outer)
        #expect(NetworkStore.applicationURLForTesting(for: outer.appending(path: "Contents/MacOS/Example")) == outer)
        #expect(NetworkStore.applicationURLForTesting(for: URL(filePath: "/usr/bin/curl")) == nil)
    }
}
