#if canImport(UIKit)
import UIKit
import SwiftUI

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.jonbobrow.Cookbook"
    private let pendingRecipesFolder = "PendingRecipes"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        extractURL()
    }

    private func extractURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            dismiss()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.showShareUI(urlString: url.absoluteString)
                            } else if let urlData = data as? Data,
                                      let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self?.showShareUI(urlString: url.absoluteString)
                            } else {
                                self?.dismiss()
                            }
                        }
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let text = data as? String,
                               let url = URL(string: text),
                               url.scheme == "http" || url.scheme == "https" {
                                self?.showShareUI(urlString: text)
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

    private func showShareUI(urlString: String) {
        let shareView = ShareExtensionView(
            urlString: urlString,
            onSave: { [weak self] recipe in
                self?.saveRecipe(recipe)
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    private func saveRecipe(_ recipe: RecipeParser.ParsedRecipe) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let folder = containerURL.appendingPathComponent(pendingRecipesFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).json"
        let fileURL = folder.appendingPathComponent(fileName)

        if let data = try? JSONEncoder().encode(recipe) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

#elseif canImport(AppKit)
import AppKit
import SwiftUI

class ShareViewController: NSViewController {

    private let appGroupID = "group.com.jonbobrow.Cookbook"
    private let pendingRecipesFolder = "PendingRecipes"

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        extractURL()
    }

    private func extractURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            dismiss()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.showShareUI(urlString: url.absoluteString)
                            } else if let urlData = data as? Data,
                                      let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                                self?.showShareUI(urlString: url.absoluteString)
                            } else {
                                self?.dismiss()
                            }
                        }
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] data, _ in
                        DispatchQueue.main.async {
                            if let text = data as? String,
                               let url = URL(string: text),
                               url.scheme == "http" || url.scheme == "https" {
                                self?.showShareUI(urlString: text)
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

    private func showShareUI(urlString: String) {
        let shareView = ShareExtensionView(
            urlString: urlString,
            onSave: { [weak self] recipe in
                self?.saveRecipe(recipe)
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: shareView)
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)
    }

    private func saveRecipe(_ recipe: RecipeParser.ParsedRecipe) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }

        let folder = containerURL.appendingPathComponent(pendingRecipesFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).json"
        let fileURL = folder.appendingPathComponent(fileName)

        if let data = try? JSONEncoder().encode(recipe) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
#endif
