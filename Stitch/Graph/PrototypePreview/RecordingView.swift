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

struct MacScreenSharingView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    
    let store: StitchStore
    
    var body: some View {
        if let document = store.currentDocument,
           document.isScreenSharing {
            ZStack {
                PreviewContent(document: document,
                               isFullScreen: true,
                               showPreviewWindow: true)

                RecordingView(dismissWindow: dismissWindow)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                dismissWindow(id: RecordingView.windowId)
            }
        }
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
        HStack {
            VStack {
                Spacer()
                
                buttonView
            }
            .padding(32)
            
            Spacer()
            
            VStack {
                Spacer()
                
                Image("AppIconDefaultDark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
            }
            .padding(32)
        }
    }
    
    @ViewBuilder
    var buttonView: some View {
        Button(action: {
            if recorder.isRecording {
                recorder.stopRecording(dismissWindow: dismissWindow)
            } else {
                recorder.startRecording(dismissWindow: dismissWindow)
            }
        }) {
            labelView
        }
        .buttonStyle(.borderless)
    }
    
    @ViewBuilder
    var labelView: some View {
        if recorder.isRecording {
            Image(systemName: "stop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22)
                .background(.ultraThinMaterial)
        } else {
            Text("Record")
                .font(.subheadline)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(26)
        }
    }
}
