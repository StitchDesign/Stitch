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
           document.isScreenRecording {
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
            .modifier(FullScreenPreviewViewModifier(document: document))
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
        store.currentDocument?.isScreenRecording = false
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

            Spacer()
        }
        .padding(16)
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

struct RecordingWatermarkView<PreviewView>: View where PreviewView: View {
    private let stitchFontColor = Color(red: 0.48, green: 0.42, blue: 0.88)
    private let appIconName = "AppIconDefaultDark"
    
    let isVisible: Bool
    @ViewBuilder var previewView: () -> PreviewView
    
    var body: some View {
        ZStack {
            previewView()
            
            if isVisible {
                watermarkWrapper
                    .padding(8)
                    .allowsHitTesting(true)
            }
        }
    }
    
    var watermarkWrapper: some View {
        HStack {
            Spacer()
            
            VStack {
                Spacer()
                
                watermark
            }
        }
    }
    
    var watermark: some View {
        HStack(spacing: .zero) {
            Image(appIconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20)
            
            Text("@stitchdesignapp")
                .font(.system(size: 12, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(stitchFontColor)
                .padding(.trailing, 4)
        }
        .opacity(0.9)
        .padding(4)
        
        // material backgrounds bug out and change opacities strangely
        .background(Color(red: 1, green: 1, blue: 1, opacity: 0.3))
        .cornerRadius(12)
    }
}
