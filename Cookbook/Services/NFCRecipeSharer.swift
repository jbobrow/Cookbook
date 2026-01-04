#if os(iOS)
import CoreNFC
import SwiftUI
import Combine

class NFCRecipeSharer: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var isSharing = false
    @Published var statusMessage = ""
    
    private var session: NFCNDEFReaderSession?
    private var recipeToShare: Recipe?
    
    func shareRecipe(_ recipe: Recipe) {
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "NFC not available on this device"
            return
        }
        
        recipeToShare = recipe
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold near another iPhone to share '\(recipe.title)'"
        session?.begin()
        isSharing = true
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // This is called when we detect NFC tags - for peer-to-peer sharing
        // iOS doesn't support peer-to-peer NFC writing in the same way
        // This would require the receiving device to be in reader mode
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first, let recipe = recipeToShare else {
            session.invalidate(errorMessage: "Unable to share recipe")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, _, error in
                guard error == nil, status == .readWrite else {
                    session.invalidate(errorMessage: "Tag not writable")
                    return
                }
                
                // Encode recipe to JSON
                do {
                    let encoder = JSONEncoder()
                    let recipeData = try encoder.encode(recipe)
                    
                    // Create NDEF payload
                    let payload = NFCNDEFPayload(
                        format: .media,
                        type: "application/json".data(using: .utf8)!,
                        identifier: "cookbook.recipe".data(using: .utf8)!,
                        payload: recipeData
                    )
                    
                    let message = NFCNDEFMessage(records: [payload])
                    
                    tag.writeNDEF(message) { error in
                        if let error = error {
                            session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                        } else {
                            session.alertMessage = "Recipe shared successfully!"
                            session.invalidate()
                            
                            DispatchQueue.main.async {
                                self.statusMessage = "Shared '\(recipe.title)' successfully"
                            }
                        }
                    }
                } catch {
                    session.invalidate(errorMessage: "Failed to encode recipe")
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isSharing = false
        }
        
        if let nfcError = error as? NFCReaderError {
            if nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                DispatchQueue.main.async {
                    self.statusMessage = "Session ended: \(nfcError.localizedDescription)"
                }
            }
        }
    }
}

// Note: NFC peer-to-peer sharing requires:
// 1. Both devices to have NFC
// 2. The receiving device to be in reader mode
// 3. An NFC tag or sticker to write to
// For direct device-to-device sharing, AirDrop is more practical
// This implementation writes to NFC tags that can then be read by other devices

#endif
