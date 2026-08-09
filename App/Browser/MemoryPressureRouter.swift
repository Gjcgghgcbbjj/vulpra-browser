import Foundation
import VulpraEngineKit

/// Wires the EngineKit host-process memory-pressure channel to the browser
/// shell without growing BrowserViewController past its ownership budget.
/// EngineKit surfaces the dispatch-source `.warning` level before UIKit's
/// late `didReceiveMemoryWarning`; the shell downgrades suggestions on
/// warning and suspends LRU background tabs on critical so the content
/// process is less likely to be selected by jetsam.
@MainActor
enum MemoryPressureRouter {
    static func attach(runtime: any EngineRuntime, controller: BrowserViewController) {
        runtime.onMemoryPressure = { [weak controller] level in
            controller?.applyMemoryPressure(level == .critical ? .heavy : .light)
        }
    }
}
