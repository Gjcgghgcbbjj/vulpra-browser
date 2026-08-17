import Foundation
import GeckoView
import UIKit

/// Architecture completion: Reader Mode.
///
/// Connects to Gecko's built-in reader mode API (GeckoView:Reader:Parse) which
/// extracts article content (title, text, byline) from a web page and renders
/// it in a clean, distraction-free view. Matches the architecture used by
/// Firefox for iOS and Safari's Reader.
final class ReaderModeController {
    weak var presenter: UIViewController?

    /// Parse the current page for reader content.
    /// Returns nil if the page is not parseable as an article.
    func parse(session: GeckoSession) async -> ReaderArticle? {
        guard session.engineView != nil else { return nil }

        let response = try? await session.dispatcher.query(
            type: "GeckoView:Reader:Parse",
            message: nil
        )

        guard let dict = response as? [String: Any?] else { return nil }

        // GeckoView:Reader:Parse returns { title, content, byline, length }
        guard let content = dict["content"] as? String, !content.isEmpty else { return nil }

        let title = (dict["title"] as? String) ?? ""
        let byline = dict["byline"] as? String
        let length = (dict["length"] as? Int) ?? content.count

        return ReaderArticle(title: title, content: content, byline: byline, length: length)
    }

    /// Parse and present in one call; shows an alert if the page isn't parseable.
    @MainActor
    func parseAndPresent(session: GeckoSession, sourceView: UIView?) async {
        if let article = await parse(session: session) {
            present(article, from: sourceView)
        } else if let presenter {
            let alert = UIAlertController(title: "Reader Unavailable",
                message: "This page cannot be displayed in Reader Mode.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
        }
    }

    /// Present the reader article in a full-screen modal.
    func present(_ article: ReaderArticle, from sourceView: UIView?) {
        guard let presenter else { return }
        let readerVC = ReaderArticleViewController(article: article)
        let nav = UINavigationController(rootViewController: readerVC)
        readerVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: readerVC, action: #selector(ReaderArticleViewController.close))
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(nav, animated: true)
    }
}

/// Parsed article content from Gecko's reader API.
struct ReaderArticle {
    let title: String
    let content: String  // HTML content
    let byline: String?
    let length: Int
}

/// Full-screen reader view with clean typography.
final class ReaderArticleViewController: UIViewController {
    private let article: ReaderArticle
    private let scrollView = UIScrollView()
    private let titleLabel = UILabel()
    private let bylineLabel = UILabel()
    private let contentLabel = UILabel()

    init(article: ReaderArticle) {
        self.article = article
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reader"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "textformat.size"),
            style: .plain, target: self, action: #selector(toggleFont))
        setupLayout()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let container = UIStackView(arrangedSubviews: [titleLabel, bylineLabel, contentLabel])
        container.axis = .vertical
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)

        titleLabel.text = article.title
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.numberOfLines = 0

        bylineLabel.text = article.byline
        bylineLabel.font = .preferredFont(forTextStyle: .subheadline)
        bylineLabel.textColor = .secondaryLabel
        bylineLabel.numberOfLines = 0
        bylineLabel.isHidden = article.byline == nil

        // Render the HTML content as plain text with basic formatting.
        // Gecko returns cleaned HTML; we use a simple attributed conversion.
        let attributed = try? NSAttributedString(
            data: article.content.data(using: .utf8) ?? Data(),
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil)
        contentLabel.attributedText = attributed
        contentLabel.font = .preferredFont(forTextStyle: .body)
        contentLabel.numberOfLines = 0

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            container.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
        ])
    }

    private var fontSizeStep = 0  // -2 to +2

    @objc private func toggleFont() {
        fontSizeStep = fontSizeStep >= 2 ? -2 : fontSizeStep + 1
        let baseSize: CGFloat = 17
        let newSize = baseSize + CGFloat(fontSizeStep * 2)
        contentLabel.font = .systemFont(ofSize: newSize)
    }

    @objc func close() { dismiss(animated: true) }
}
