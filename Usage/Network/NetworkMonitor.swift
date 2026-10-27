//
//  NetworkMonitor.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import AppKit
import Darwin
import Foundation
import Synchronization

nonisolated enum NetworkMonitor {
    enum Failure: Error {
        case invalidOutput(String)
        case terminalSetup(Int32)
        case stopped
    }

    private struct Parser {
        var previousSampleAt: ContinuousClock.Instant? = nil
        var sampleAt: ContinuousClock.Instant? = nil
        var processes: [NetworkSample.ProcessTraffic] = []

        mutating func consume(_ line: String, at instant: ContinuousClock.Instant) throws -> NetworkSample? {
            if line == ",bytes_in,bytes_out," {
                var sample: NetworkSample?
                if let previousSampleAt = self.previousSampleAt, let sampleAt = self.sampleAt {
                    let duration: Duration = previousSampleAt.duration(to: sampleAt)
                    let seconds: Double = .init(duration.components.seconds)
                        + Double(duration.components.attoseconds) / 1e18
                    sample = NetworkSample(processes: self.processes, interval: seconds)
                }

                // The first section contains lifetime counters even in delta mode, so it is only a baseline.
                self.previousSampleAt = self.sampleAt
                self.sampleAt = instant
                self.processes.removeAll(keepingCapacity: true)
                return sample
            }

            guard self.sampleAt != nil else {
                throw Failure.invalidOutput(line)
            }

            let fields: [Substring] = line.split(separator: ",", omittingEmptySubsequences: false)
            guard
                fields.count >= 4, fields[fields.count - 1].isEmpty,
                let bytesIn = UInt64(fields[fields.count - 3]),
                let bytesOut = UInt64(fields[fields.count - 2]) else
            {
                throw Failure.invalidOutput(line)
            }

            // Process names can contain commas and dots. Only the final numeric suffix identifies the PID.
            let label: String = fields.dropLast(3).joined(separator: ",")
            guard
                let dot = label.lastIndex(of: "."),
                let pid = Int32(label[label.index(after: dot)...]), pid > 0,
                dot != label.startIndex else
            {
                throw Failure.invalidOutput(line)
            }

            self.processes.append(.init(
                pid: pid,
                name: String(label[..<dot]),
                bytesIn: bytesIn,
                bytesOut: bytesOut,
            ))
            return nil
        }
    }

    @concurrent
    static func run(onSample: @MainActor @Sendable (NetworkSample) -> Void) async throws {
        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            throw Failure.terminalSetup(errno)
        }

        let reader: FileHandle = .init(fileDescriptor: master, closeOnDealloc: true)
        let writer: FileHandle = .init(fileDescriptor: slave, closeOnDealloc: true)
        let process: Process = .init()
        process.executableURL = URL(filePath: "/usr/bin/nettop")
        process.arguments = ["-P", "-L", "0", "-n", "-x", "-d", "-s", "1", "-t", "external", "-J", "bytes_in,bytes_out"]
        process.standardInput = FileHandle.nullDevice
        // nettop block-buffers pipes. A terminal makes it flush every sample instead of waiting for a full buffer.
        process.standardOutput = writer
        process.standardError = writer
        let isTerminating: Mutex<Bool> = .init(false)
        // App termination does not cancel Swift tasks, and nettop can outlive a closed terminal.
        let terminationObserver: any NSObjectProtocol = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil,
        ) { _ in
            isTerminating.withLock { $0 = true }
            if process.isRunning {
                process.terminate()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(terminationObserver)
            if process.isRunning {
                process.terminate()
            }
            try? reader.close()
            try? writer.close()
        }

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try process.run()
            try writer.close()
            // Cancellation or app termination can arrive between the pre-launch check and Process.run().
            if Task.isCancelled || isTerminating.withLock({ $0 }) {
                process.terminate()
                throw CancellationError()
            }

            var parser: Parser = .init()
            for try await line in reader.bytes.lines {
                try Task.checkCancellation()
                if let sample = try parser.consume(line, at: .now) {
                    await onSample(sample)
                }
            }
            throw Failure.stopped
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }

    #if DEBUG
        static func samplesForTesting(_ lines: [(String, ContinuousClock.Instant)]) throws -> [NetworkSample] {
            var parser: Parser = .init()
            return try lines.compactMap { try parser.consume($0.0, at: $0.1) }
        }
    #endif
}
