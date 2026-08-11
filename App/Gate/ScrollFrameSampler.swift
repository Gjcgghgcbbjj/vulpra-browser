import Foundation
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
///
/// Long-frame policy (recording fidelity): a foreground gap longer than the
/// sample ceiling is CLAMPED to 5.0s and still recorded, so a real main-thread
/// stall (the user-facing "very laggy" case) trips the max/stall budget
/// instead of being silently dropped. Gaps that span a background/foreground
/// transition are excluded by resetting the frame anchor on the UIApplication
/// lifecycle notifications: a resume interval measures the whole backgrounded
/// duration, which is not a main-thread stall.
@MainActor
final class ScrollFrameSampler: NSObject {
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
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(appDidEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(appWillEnterForeground),
                           name: UIApplication.willEnterForegroundNotification, object: nil)
        center.addObserver(self, selector: #selector(appWillEnterForeground),
                           name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// Upper bound applied to a recorded interval. A gap above this is a real
    /// foreground stall (or a simulator host pause), not display jitter: it is
    /// clamped to the ceiling so it still trips the stall budget while the
    /// p95 stays comparable across hosts.
    private static let longFrameCeiling: CFTimeInterval = 5.0

    @objc private func frame(_ link: CADisplayLink) {
        if let last = lastTimestamp {
            let interval = link.timestamp - last
            // Record every non-negative interval. Long foreground gaps are
            // clamped, never dropped, so max/stall evidence reflects them.
            if interval >= 0 { intervals.append(min(interval, Self.longFrameCeiling)) }
        }
        lastTimestamp = link.timestamp
        if let startedAt, CACurrentMediaTime() - startedAt >= duration {
            finish()
        }
    }

    @objc private func appWillEnterForeground() {
        // The resume interval would span the whole backgrounded duration and
        // is not a main-thread stall; start the next measurement fresh.
        lastTimestamp = nil
    }

    @objc private func appDidEnterBackground() {
        lastTimestamp = nil
    }

    /// Stops the sampler and returns the frame statistics.
    func finish() -> ScrollFrameStats? {
        displayLink?.invalidate()
        displayLink = nil
        NotificationCenter.default.removeObserver(self)
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
