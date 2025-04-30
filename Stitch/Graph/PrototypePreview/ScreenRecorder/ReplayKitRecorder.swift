//
//  ReplayKitRecorder.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/29/25.
//

import SwiftUI
import ReplayKit
import UIKit

@MainActor @Observable
final class ReplayKitRecorder: NSObject {
    private let delegate: ReplayKitRecorderDelegate
    
    var isRecording = false
    
#if targetEnvironment(macCatalyst)
    init(dismissWindow: DismissWindowAction) {
        self.delegate = .init(dismissWindow: dismissWindow)
    }
#else
    override init() {
        self.delegate = .init()
        super.init()
    }
#endif
    
    @MainActor
    func startRecording(dismissWindow: DismissWindowAction) {
        let recorder = RPScreenRecorder.shared()
        guard !recorder.isRecording else { return }
        
        recorder.startRecording { [weak self] error in
            if let error = error {
                print("Error starting recording: \(error.localizedDescription)")
#if targetEnvironment(macCatalyst)
                dismissWindow(id: RecordingView.windowId)
#endif
            } else {
                print("Started recording.")
                self?.isRecording = true
            }
        }
    }
    
    @MainActor
    func stopRecording(dismissWindow: DismissWindowAction) {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isRecording else { return }
        
        recorder.stopRecording { [weak self] (previewVC, error) in
            Task { @MainActor in
                if let error = error {
                    print("Error stopping recording: \(error.localizedDescription)")
                } else if let previewVC = previewVC {
                    print("Stopped recording, showing preview.")
                    self?.presentPreview(previewVC,
                                         dismissWindow: dismissWindow)
                } else {
                    print("Stopped recording, no preview available.")
                }
                
                self?.isRecording = false
            }
        }
    }
    
    private func presentPreview(_ previewVC: RPPreviewViewController,
                                dismissWindow: DismissWindowAction) {
        previewVC.previewControllerDelegate = self.delegate
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let rootVC = window.rootViewController {
            
            // 🛠 Fix: force a form sheet presentation on iPad to avoid crash
            previewVC.modalPresentationStyle = .formSheet
            
            rootVC.present(previewVC, animated: true)
        }
    }
}

// MARK: - RPPreviewViewControllerDelegate
@MainActor
final class ReplayKitRecorderDelegate: NSObject, RPPreviewViewControllerDelegate {
#if targetEnvironment(macCatalyst)
    let dismissWindow: DismissWindowAction

    init(dismissWindow: DismissWindowAction) {
        self.dismissWindow = dismissWindow
    }
#endif
    
    nonisolated func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        Task { @MainActor [weak self, weak previewController] in
            previewController?.dismiss(animated: true, completion: nil)
            
#if targetEnvironment(macCatalyst)
            // Dismiss new window if on Mac
            self?.dismissWindow(id: RecordingView.windowId)
#endif
        }
    }
}
