import Foundation
import os
import QuartzCore
import UIKit

#if DEBUG
/// Main-thread frame-interval sampler for the Simulator scroll gate.
///
/// The iOS Simulator cannot inject touch input (no simctl swipe channel), so
/// the scroll-performance gate drives the page with in-page JS scrolling while
/// this sampler measures the App's main-thread render cadence with a
/// CADisplayLink. A frame interval at or below the display's nominal budget
/// means the main thread is keeping up with the compositor; intervals above
/// 25 ms (1.5x the 60 Hz budget of 16.67 ms) are hitches, and intervals above
/// 100 ms are main-thread stalls (R1 acceptance: p95 below 20 ms, no stall
/// above 100 ms, hitch rate below 1%).
///
/// The host display may run at 60 or 120 Hz in the Simulator; the raw refresh
/// rate is recorded as evidence and hitch/stall thresholds are defined against
/// the pinned 60 Hz budget so results are comparable across hosts.
@MainActor
final class ScrollFrameSampler: NSObject {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "gate")
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var intervals: [Double] = []
    private var startedAt: CFTimeInterval?
    private let duration: TimeInterval

    init(duration: TimeInterval = 10) {
        self.duration = duration
        super.init()
    }

    private var refreshHz = 0

    func start() {
        guard displayLink == nil else { return }
        refreshHz = Int(UIScreen.main.maximumFramesPerSecond)
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        startedAt = CACurrentMediaTime()
        lastTimestamp = nil
        intervals.removeAll()
    }

    @objc private func frame(_ link: CADisplayLink) {
        if let last = lastTimestamp {
            let interval = link.timestamp - last
            if interval >= 0, interval < 5 { intervals.append(interval) }
        }
        lastTimestamp = link.timestamp
        if let startedAt, CACurrentMediaTime() - startedAt >= duration {
            finish()
        }
    }

    /// Stops the sampler and returns the frame statistics.
    func finish() -> ScrollFrameStats? {
        displayLink?.invalidate()
        displayLink = nil
        guard !intervals.isEmpty else { return nil }
        let ordered = intervals.sorted()
        let p95Index = min(max(Int(ceil(Double(ordered.count) * 0.95)) - 1, 0), ordered.count - 1)
        let p95Ms = ordered[p95Index] * 1000
        let maxMs = (ordered.last ?? 0) * 1000
        let hitches = ordered.filter { $0 * 1000 > 25 }.count
        let stalls = ordered.filter { $0 * 1000 > 100 }.count
        return ScrollFrameStats(
            sampledFrames: ordered.count,
            p95FrameIntervalMs: round(p95Ms * 10) / 10,
            maxFrameIntervalMs: round(maxMs * 10) / 10,
            hitchCount: hitches,
            stallCount: stalls,
            displayRefreshHz: refreshHz
        )
    }
}

/// Frame statistics emitted as gate evidence.
struct ScrollFrameStats {
    let sampledFrames: Int
    let p95FrameIntervalMs: Double
    let maxFrameIntervalMs: Double
    let hitchCount: Int
    let stallCount: Int
    let displayRefreshHz: Int
}
#endif
