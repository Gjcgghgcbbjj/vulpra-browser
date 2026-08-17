import UIKit

final class OmniboxSuggestionsView: UIView, UITableViewDataSource, UITableViewDelegate {
    private let material = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var suggestions: [OmniboxSuggestion] = []
    var onSelect: ((OmniboxSuggestion) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 16
        material.layer.cornerRadius = 18
        material.clipsToBounds = true
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 58
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Suggestion")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            material.topAnchor.constraint(equalTo: topAnchor), material.leadingAnchor.constraint(equalTo: leadingAnchor),
            material.trailingAnchor.constraint(equalTo: trailingAnchor), material.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.topAnchor.constraint(equalTo: material.contentView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor),
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(_ values: [OmniboxSuggestion]) {
        suggestions = values
        isHidden = values.isEmpty
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { suggestions.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let value = suggestions[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Suggestion", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = value.title
        content.secondaryText = value.detail
        content.image = UIImage(systemName: value.symbol)
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect?(suggestions[indexPath.row]); update([])
    }
}
