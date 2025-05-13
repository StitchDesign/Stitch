//
//  StitchApp.swift
//  Stitch
//
//  Created by cjc on 11/1/20.
//

import SwiftUI
import StitchSchemaKit
import Sentry
import FirebaseCore
import FirebaseAnalytics
import TipKit

@main @MainActor
struct StitchApp: App {
    @Environment(\.dismissWindow) private var dismissWindow
    
    // MARK: VERY important to pass the store StateObject into each view for perf
    @State private var store = StitchStore()
    
    private static var isFirebaseConfigValid: Bool {
        guard
            let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
            let options = FirebaseOptions(contentsOfFile: url.path)
        else { return false }

        return [
            options.apiKey?.isEmpty,
            options.googleAppID.isEmpty,
            options.projectID?.isEmpty
        ].allSatisfy { $0 == false }
    }
    
    private static func configureFirebaseIfPossible() {
        guard FirebaseApp.app() == nil else { return }
        guard isFirebaseConfigValid else {
            print("⚠️  Firebase configuration skipped – incomplete GoogleService-Info.plist")
            return
        }
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            // iPad uses StitchRouter to use the project zoom in/out animation
            StitchRootView(store: self.store)
                .onAppear {
//                    StitchAITrainingData.validateTrainingData(from: "stitch-training")
                    
                    // Load and configure the state of all the tips of the app
                    try? Tips.configure()
                    
                    // For testing
                    #if DEV_DEBUG
                    try? Tips.resetDatastore()
                    #endif
                    
                    dispatch(DirectoryUpdatedOnAppOpen())
                    
                    SentrySDK.start { options in
                        guard let secrets = try? Secrets() else {
                            return
                        }
                        
                        options.dsn = secrets.sentryDSN
                        options.enableMetricKit = true
                        options.enableMetricKitRawPayload = true
                        options.debug = false
                    }
                    
                    #if !DEBUG
                    Self.configureFirebaseIfPossible()
                    #endif

                    // Close mac sharing window in case open
                    #if targetEnvironment(macCatalyst)
                    dismissWindow(id: RecordingView.windowId)
                    #endif

                }
                .environment(self.store)
                .environment(self.store.environment)
                .environment(self.store.environment.fileManager)
            // Inject theme as environment variable
                .environment(\.appTheme, self.store.appTheme)
                .environment(\.edgeStyle, self.store.edgeStyle)
        }

        // TODO: why does XCode complain about `.windowStyle not available on iOS` even when using `#if targetEnvironment(macCatalyst)`?
        // TODO: why do `!os(iOS)` or `os(macOS)` statements not seem to run?
        // #if targetEnvironment(macCatalyst)
        // #if os(macOS)
        // #if !os(iOS)
        //        .windowStyle(HiddenTitleBarWindowStyle())
        //        .windowStyle(.hiddenTitleBar)
        //        #endif
        .commands {
            StitchCommands(store: store,
                           activeReduxFocusedField: store.currentDocument?.reduxFocusedField)
          
        }
        
        #if targetEnvironment(macCatalyst)
        WindowGroup("Screen Sharing", id: "mac-screen-sharing") {
            MacScreenSharingView(store: store)
        }
        #endif
    }
}
