import UIKit

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.jonbobrow.Cookbook"
    private let pendingURLKey = "pendingImportURL"

    private let checkmarkView = UIImageView()
    private let statusLabel = UILabel()

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

        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        checkmarkView.image = UIImage(systemName: "arrow.down.circle", withConfiguration: config)
        checkmarkView.tintColor = .systemGreen
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(checkmarkView)

        statusLabel.text = "Saving to Cookbook..."
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .label
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 200),
            card.heightAnchor.constraint(equalToConstant: 140),

            checkmarkView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            checkmarkView.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            checkmarkView.widthAnchor.constraint(equalToConstant: 50),
            checkmarkView.heightAnchor.constraint(equalToConstant: 50),

            statusLabel.topAnchor.constraint(equalTo: checkmarkView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
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
                                self?.saveAndDismiss(urlString: url.absoluteString)
                            } else if let urlData = data as? Data,
                                      let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self?.saveAndDismiss(urlString: url.absoluteString)
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
                                self?.saveAndDismiss(urlString: text)
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

    private func saveAndDismiss(urlString: String) {
        // Save the URL to the shared App Group container
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(urlString, forKey: pendingURLKey)
        sharedDefaults?.synchronize()

        // Show success state
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        checkmarkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        statusLabel.text = "Saved! Open Cookbook."

        // Dismiss after a brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func showError() {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        checkmarkView.image = UIImage(systemName: "xmark.circle", withConfiguration: config)
        checkmarkView.tintColor = .systemRed
        statusLabel.text = "Could not read URL"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
