//
//  RecordingView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/28/25.
//

import SwiftUI
import ReplayKit
import UIKit

#if targetEnvironment(macCatalyst)
struct MacScreenSharingView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var screenSharingProjectObserver = PreviewWindowSizing()
    @State private var showFullScreenAnimateCompleted = true
    @StateObject private var showFullScreen = AnimatableBool(true)

    let store: StitchStore
    
    var body: some View {
        if let document = store.currentDocument,
           document.isScreenSharing {
            ZStack {
                ProjectWindowSizeReader(previewWindowSizing: self.screenSharingProjectObserver,
                                        previewWindowSize: document.previewWindowSize,
                                        isFullScreen: true,
                                        showFullScreenAnimateCompleted: $showFullScreenAnimateCompleted,
                                        showFullScreenObserver: showFullScreen,
                                        menuHeight: 0)
                
                PreviewContent(document: document,
                               isFullScreen: true,
                               showPreviewWindow: true,
                               previewWindowSizing: screenSharingProjectObserver)

                RecordingView(dismissWindow: dismissWindow)
            }
            .onDisappear {
                dismissRecordingWindow()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                dismissRecordingWindow()
            }
        }
    }
    
    func dismissRecordingWindow() {
        dismissWindow(id: RecordingView.windowId)
        store.currentDocument?.isScreenSharing = false
    }
}
#endif

struct RecordingView: View {
    static let windowId = "mac-screen-sharing"
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var recorder: ReplayKitRecorder
    
#if targetEnvironment(macCatalyst)
    init(dismissWindow: DismissWindowAction) {
        self.recorder = .init(dismissWindow: dismissWindow)
    }
#else
    init() {
        self.recorder = .init()
    }
#endif
    
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
        Text(recorder.isRecording ? "Stop" : "Record")
            .font(.subheadline)
            .opacity(0.6)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(26)
    }
}
