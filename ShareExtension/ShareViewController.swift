import UIKit

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.jonbobrow.Cookbook"
    private let pendingURLKey = "pendingImportURL"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleSharedURL()
    }

    private func handleSharedURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            dismiss()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.save(urlString: url.absoluteString)
                            } else if let urlData = data as? Data,
                                      let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self?.save(urlString: url.absoluteString)
                            } else {
                                self?.dismiss()
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
                                self?.save(urlString: text)
                            } else {
                                self?.dismiss()
                            }
                        }
                    }
                    return
                }
            }
        }

        dismiss()
    }

    private func save(urlString: String) {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(urlString, forKey: pendingURLKey)
        sharedDefaults?.synchronize()
        showConfirmation()
    }

    private func showConfirmation() {
        let backdrop = UIView()
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.alpha = 0
        view.addSubview(backdrop)

        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.15
        card.layer.shadowRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(card)

        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: config))
        icon.tintColor = .systemGreen
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(icon)

        let label = UILabel()
        label.text = "Saved to Cookbook"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: backdrop.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 200),

            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        card.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            backdrop.alpha = 1
            card.transform = .identity
        }

        UIView.animate(withDuration: 0.2, delay: 1.0) {
            backdrop.alpha = 0
            card.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { [weak self] _ in
            self?.dismiss()
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
