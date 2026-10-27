//
//  NetworkStore.swift
//
//  Copyright © 2026 Rivia Corp s.r.o.
//

import AppKit
import Darwin
import Observation

@Observable
final class NetworkStore {
    enum State {
        case loading
        case live([ApplicationBandwidth])
        case failed(String)
    }

    private(set) var state: State = .loading

    func monitor() async {
        self.state = .loading
        do {
            try await NetworkMonitor.run { sample in
                guard !Task.isCancelled else {
                    return
                }

                var applications: [ApplicationBandwidth.Identity: ApplicationBandwidth] = [:]
                for traffic in sample.processes where traffic.bytesIn > 0 || traffic.bytesOut > 0 {
                    // Swift cannot import PROC_PIDPATHINFO_MAXSIZE; libproc defines it as 4 * MAXPATHLEN.
                    var path: [CChar] = .init(repeating: 0, count: 4 * Int(MAXPATHLEN))
                    let length: Int32 = proc_pidpath(traffic.pid, &path, UInt32(path.count))
                    let applicationURL: URL? = if
                        length > 0,
                        let executable = String(
                            bytes: path.prefix(Int(length)).map { UInt8(bitPattern: $0) },
                            encoding: .utf8,
                        )
                    {
                        Self.applicationURL(for: URL(filePath: executable))
                    } else if let bundleURL = NSRunningApplication(processIdentifier: traffic.pid)?.bundleURL {
                        Self.applicationURL(for: bundleURL)
                    } else {
                        nil
                    }

                    let identity: ApplicationBandwidth.Identity
                    let name: String
                    let icon: NSImage?
                    if let applicationURL {
                        identity = .application(applicationURL)
                        name = FileManager.default.displayName(atPath: applicationURL.path)
                        icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
                    } else {
                        // Background services and command-line processes have no application bundle.
                        identity = .process(traffic.pid)
                        name = traffic.name
                        icon = nil
                    }

                    var bandwidth: ApplicationBandwidth = applications[identity] ?? .init(
                        id: identity,
                        name: name,
                        icon: icon,
                        download: 0,
                        upload: 0,
                    )
                    bandwidth.download += Double(traffic.bytesIn) / sample.interval
                    bandwidth.upload += Double(traffic.bytesOut) / sample.interval
                    applications[identity] = bandwidth
                }

                self.state = .live(applications.values.sorted {
                    let lhs: Double = $0.download + $0.upload
                    let rhs: Double = $1.download + $1.upload
                    return lhs == rhs ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : lhs > rhs
                })
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }

            var message: String = "Could not monitor network activity. Try again."
            #if DEBUG
                message += "\n\(error)"
            #endif
            self.state = .failed(message)
        }
    }

    private static func applicationURL(for executableURL: URL) -> URL? {
        var url: URL = executableURL
        var application: URL?
        while url.path != "/" {
            if url.pathExtension == "app" {
                // Browser and Electron helpers are nested apps; attribute their traffic to the outer app.
                application = url
            }
            url.deleteLastPathComponent()
        }
        return application
    }

    #if DEBUG
        static func applicationURLForTesting(for executableURL: URL) -> URL? {
            self.applicationURL(for: executableURL)
        }
    #endif
}
