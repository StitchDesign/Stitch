//
//  RecordingView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/28/25.
//

import SwiftUI
import ReplayKit
import UIKit

@MainActor @Observable
final class ReplayKitRecorder: NSObject {
    private let recorder: RPScreenRecorder
    private let delegate: ReplayKitRecorderDelegate
    
    var isRecording = false
    
    init(dismissWindow: DismissWindowAction) {
        self.recorder = RPScreenRecorder.shared()
        self.delegate = .init(dismissWindow: dismissWindow)
    }
    
    @MainActor
    func startRecording(dismissWindow: DismissWindowAction) {
        guard !recorder.isRecording else { return }
        
        self.recorder.startRecording { [weak self] error in
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
    let dismissWindow: DismissWindowAction
    
    init(dismissWindow: DismissWindowAction) {
        self.dismissWindow = dismissWindow
    }
    
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

struct RecordingViewWrapper: View {
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        RecordingView(dismissWindow: dismissWindow)
    }
}

struct RecordingView: View {
    static let windowId = "mac-screen-sharing"
    
    let dismissWindow: DismissWindowAction
    @State private var recorder: ReplayKitRecorder
    
    init(dismissWindow: DismissWindowAction) {
        self.dismissWindow = dismissWindow
        self.recorder = .init(dismissWindow: dismissWindow)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(recorder.isRecording ? "Recording..." : "Not Recording")
                .font(.title)
                .padding()
                .frame(width: 200, height: 50)
            
            Button(action: {
                if recorder.isRecording {
                    recorder.stopRecording(dismissWindow: dismissWindow)
                } else {
                    recorder.startRecording(dismissWindow: dismissWindow)
                }
            }) {
                Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                    .frame(width: 200, height: 50)
                    .background(recorder.isRecording ? Color.red : Color.green)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}


#Preview {
    RecordingViewWrapper()
}
