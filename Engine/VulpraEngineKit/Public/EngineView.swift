import UIKit

@MainActor
public protocol EngineView: AnyObject {
    var view: UIView { get }
    func setVisible(_ visible: Bool)
}
