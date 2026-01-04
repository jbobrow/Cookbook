import SwiftUI

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#elseif os(macOS)
import AppKit

struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            guard let url = items.first as? URL else { return }
            
            let picker = NSSharingServicePicker(items: [url])
            picker.show(
                relativeTo: .zero,
                of: view,
                preferredEdge: .minY
            )
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
