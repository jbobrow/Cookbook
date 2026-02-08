import UIKit
import Social

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedURL()
    }

    private func handleSharedURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.openApp(with: url.absoluteString)
                            } else if let urlData = data as? Data,
                                      let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self?.openApp(with: url.absoluteString)
                            } else {
                                self?.completeRequest()
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
                                self?.openApp(with: text)
                            } else {
                                self?.completeRequest()
                            }
                        }
                    }
                    return
                }
            }
        }

        completeRequest()
    }

    private func openApp(with urlString: String) {
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let appURL = URL(string: "cookbook://import?url=\(encoded)") else {
            completeRequest()
            return
        }

        // Open the containing app via the extension context
        extensionContext?.open(appURL) { [weak self] _ in
            self?.completeRequest()
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
