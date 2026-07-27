import UIKit

@MainActor
public protocol EngineView: AnyObject {
    var contentView: UIView? { get }

    func setVisible(_ visible: Bool)
    func setFocused(_ focused: Bool)
}
