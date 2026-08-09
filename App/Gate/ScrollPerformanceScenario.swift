import Foundation
import os
import UIKit

#if DEBUG
/// Scroll-performance gate scenario (R1): loads a tall page that auto-scrolls
/// in-page JS while a CADisplayLink samples the App main-thread render cadence.
///
/// The Simulator cannot inject touch input, so the scroll is driven by the
/// fixture page itself (`requestAnimationFrame` scroll steps). This exercises
/// the same compositor/rendering path a user scroll would take (Gecko renders
/// new frames for every scroll position) and the same App main-thread work the
/// R0/A2 gates already cover, but adds the frame-interval evidence the R1
/// acceptance requires: p95 frame interval below 20 ms, no main-thread stall
/// above 100 ms, hitch rate below 1% (60 Hz budget, hitch > 25 ms).
///
/// The harness triggers it through the loopback GateDispatchServer after the
/// fixture page completes its initial load and asserts the scenario completes
/// while the app stays alive. Kept in its own DEBUG file so the browser owner
/// stays under the product line budget.
extension BrowserViewController {
    func runScrollPerformanceScenario(url: URL, seconds: Int = 10) {
        let gateLogger = Logger(subsystem: "com.vulpra.browser", category: "gate")
        let duration = max(3, min(seconds, 30))
        gateLogger.notice("gate_scenario=scroll-performance started url=\(url.absoluteString, privacy: .public) seconds=\(duration)")
        guard let tab = tabManager.selectedTab else {
            gateLogger.notice("gate_scenario=scroll-performance aborted-no-selected-tab")
            return
        }
        open(url)
        // Poll the tab's loading flag on the main queue until the fixture
        // page settles (or a hard deadline), then start the frame window.
        waitForIdleLoad(tab: tab, gateLogger: gateLogger, url: url, duration: duration, waited: 0)
    }

    private func waitForIdleLoad(tab: BrowserTab, gateLogger: Logger, url: URL, duration: Int, waited: Int) {
        let deadline = 20
        if waited >= deadline {
            gateLogger.notice("gate_scenario=scroll-performance load-settle-deadline waited=\(waited)")
        } else if tab.isLoading {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.waitForIdleLoad(tab: tab, gateLogger: gateLogger, url: url, duration: duration, waited: waited + 1)
            }
            return
        } else {
            gateLogger.notice("gate_scenario=scroll-performance load-settled waited=\(waited)")
        }
        // Brief settle lets the final load frame flush before the sample window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.sampleScroll(tab: tab, gateLogger: gateLogger, url: url, duration: duration)
        }
    }

    private func sampleScroll(tab: BrowserTab, gateLogger: Logger, url: URL, duration: Int) {
        let sampler = ScrollFrameSampler(duration: TimeInterval(duration))
        sampler.start()
        gateLogger.notice("gate_scenario=scroll-performance sampling-started url=\(url.absoluteString, privacy: .public)")
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(duration) + 0.5) {
            guard let stats = sampler.finish() else {
                gateLogger.notice("gate_scenario=scroll-performance aborted-no-frames")
                return
            }
            gateLogger.notice(
                "gate_scenario=scroll-performance completed url=\(url.absoluteString, privacy: .public) "
                + "sampled=\(stats.sampledFrames) p95=\(stats.p95FrameIntervalMs) "
                + "max=\(stats.maxFrameIntervalMs) hitches=\(stats.hitchCount) "
                + "stalls=\(stats.stallCount) refreshHz=\(stats.displayRefreshHz)"
            )
        }
    }
}
#endif
