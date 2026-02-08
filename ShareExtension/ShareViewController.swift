import UIKit

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.jonbobrow.Cookbook"
    private let pendingURLKey = "pendingImportURL"

    private let iconView = UIImageView()
    private let statusLabel = UILabel()
    private var openButton: UIButton?
    private var card: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        setupUI()
        handleSharedURL()
    }

    private func setupUI() {
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        self.card = card

        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        iconView.image = UIImage(systemName: "arrow.down.circle", withConfiguration: config)
        iconView.tintColor = .systemGreen
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)

        statusLabel.text = "Saving..."
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .label
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 220),

            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    private func handleSharedURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.saveAndOpenApp(urlString: url.absoluteString)
                            } else if let urlData = data as? Data,
                                      let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self?.saveAndOpenApp(urlString: url.absoluteString)
                            } else {
                                self?.showError()
                            }
                        }
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let text = data as? String,
                               let url = URL(string: text),
                               url.scheme == "http" || url.scheme == "https" {
                                self?.saveAndOpenApp(urlString: text)
                            } else {
                                self?.showError()
                            }
                        }
                    }
                    return
                }
            }
        }

        showError()
    }

    private func saveAndOpenApp(urlString: String) {
        // Save the URL to the shared App Group container
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(urlString, forKey: pendingURLKey)
        sharedDefaults?.synchronize()

        // Build the app URL
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let appURL = URL(string: "cookbook://import?url=\(encoded)") else {
            showSavedWithButton()
            return
        }

        // Try to open the app directly
        extensionContext?.open(appURL) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // App opened, dismiss the extension
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                } else {
                    // Couldn't open directly, show button
                    self?.showSavedWithButton()
                }
            }
        }
    }

    private func showSavedWithButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        iconView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        statusLabel.text = "Recipe URL saved!"

        // Remove the bottom constraint on statusLabel to make room for button
        card?.constraints.forEach { constraint in
            if constraint.firstItem as? UILabel === statusLabel && constraint.firstAttribute == .bottom {
                constraint.isActive = false
            }
        }

        let button = UIButton(type: .system)
        button.setTitle("Open Cookbook", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openButtonTapped), for: .touchUpInside)
        card?.addSubview(button)
        self.openButton = button

        if let card = card {
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
                button.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
                button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
                button.heightAnchor.constraint(equalToConstant: 44),
                button.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            ])
        }
    }

    @objc private func openButtonTapped() {
        guard let encoded = UserDefaults(suiteName: appGroupID)?.string(forKey: pendingURLKey)?
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let appURL = URL(string: "cookbook://import?url=\(encoded)") else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        extensionContext?.open(appURL) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func showError() {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        iconView.image = UIImage(systemName: "xmark.circle", withConfiguration: config)
        iconView.tintColor = .systemRed
        statusLabel.text = "Could not read URL"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
