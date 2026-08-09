import Foundation
import os
import UIKit

#if DEBUG
/// v1 gate scenario: exercises the hidden-session suspend/activate path while
/// a page is still loading. Opens `url` in the current tab, switches to a
/// fresh second tab ~1s later, then back to the original tab ~1s after that.
/// The R0 harness triggers it through the loopback GateDispatchServer after
/// the measured warm navigation completes and asserts the scenario completes
/// while the app stays alive. Kept in its own DEBUG file so the browser owner
/// stays under the product line budget.
extension BrowserViewController {
    func runTabSwitchDuringLoadScenario(url: URL) {
        let gateLogger = Logger(subsystem: "com.vulpra.browser", category: "gate")
        gateLogger.notice("gate_scenario=tab-switch-during-load started url=\(url.absoluteString, privacy: .public)")
        guard let first = tabManager.selectedTab else {
            gateLogger.notice("gate_scenario=tab-switch-during-load aborted-no-selected-tab")
            return
        }
        open(url)
        let second = tabManager.newTab(url: nil, privateMode: false, select: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            guard self.tabManager.tabs.contains(where: { $0 === second }) else {
                gateLogger.notice("gate_scenario=tab-switch-during-load aborted-tab-closed")
                return
            }
            gateLogger.notice("gate_scenario=tab-switch-during-load switching-to-second")
            self.tabManager.select(second)
            self.showSelectedTab()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                guard self.tabManager.tabs.contains(where: { $0 === first }),
                      self.tabManager.tabs.contains(where: { $0 === second }) else {
                    gateLogger.notice("gate_scenario=tab-switch-during-load aborted-tab-closed")
                    return
                }
                gateLogger.notice("gate_scenario=tab-switch-during-load switching-back-to-first")
                self.tabManager.select(first)
                self.showSelectedTab()
                gateLogger.notice("gate_scenario=tab-switch-during-load completed")
            }
        }
    }
}
#endif
