import UIKit

/// Annex 78: hardware-keyboard chrome shortcuts (Cmd+T/L/R/[/]/W/1-9).
/// Engine-side keyboard navigation (APZ key events) stays a known limitation
/// (annex 50); text input already works via the UITextInput bridge (annex 37).
extension BrowserViewController {
    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = [
            UIKeyCommand(title: VulpraL10n.text("tab.new"), action: #selector(handleKeyNewTab), input: "t", modifierFlags: .command),
            UIKeyCommand(title: VulpraL10n.text("keyboard.focus_address"), action: #selector(handleKeyFocusAddress), input: "l", modifierFlags: .command),
            UIKeyCommand(title: VulpraL10n.text("browser.reload"), action: #selector(handleKeyReload), input: "r", modifierFlags: .command),
            UIKeyCommand(title: VulpraL10n.text("browser.back"), action: #selector(handleKeyBack), input: "[", modifierFlags: .command),
            UIKeyCommand(title: VulpraL10n.text("browser.forward"), action: #selector(handleKeyForward), input: "]", modifierFlags: .command),
            UIKeyCommand(title: VulpraL10n.text("keyboard.close_tab"), action: #selector(handleKeyCloseTab), input: "w", modifierFlags: .command),
        ]
        for number in 1...9 {
            commands.append(UIKeyCommand(title: VulpraL10n.format("keyboard.tab_number", number), action: #selector(handleKeySwitchTab(_:)),
                                         input: String(number), modifierFlags: .command))
        }
        return commands
    }

    @objc private func handleKeyNewTab() { _ = tabManager.newTab(url: nil, privateMode: false); showSelectedTab() }
    @objc private func handleKeyFocusAddress() { chrome.focusAddress() }
    @objc private func handleKeyReload() { browserChromeDidRequestReloadOrStop(chrome) }
    @objc private func handleKeyBack() { tabManager.selectedTab?.goBack() }
    @objc private func handleKeyForward() { tabManager.selectedTab?.goForward() }
    @objc private func handleKeyCloseTab() { tabManager.selectedTab.map(tabManager.close) }
    @objc private func handleKeySwitchTab(_ sender: UIKeyCommand) {
        guard let input = sender.input, let number = Int(input), number >= 1 else { return }
        let tabs = tabManager.tabs
        guard number <= tabs.count else { return }
        tabManager.select(tabs[number - 1]); showSelectedTab()
    }
}
