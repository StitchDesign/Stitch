//
//  StitchApp.swift
//  Stitch
//
//  Created by cjc on 11/1/20.
//

import SwiftUI
import StitchSchemaKit
import Sentry

@main @MainActor
struct StitchApp: App {
    @State private var store = StitchStore()
    
    // MARK: VERY important to pass the store StateObject into each view for perf
    var body: some Scene {
        WindowGroup {

            // iPad uses StitchRouter to use the project zoom in/out animation
            StitchRootView(store: self.store)
                .onAppear {
                    dispatch(DirectoryUpdated())
                    SentrySDK.start { options in
                            options.dsn = "https://66b7eaf513146c5d872f3461723ee290@o4508718150189056.ingest.us.sentry.io/4508718152744960"
                            options.debug = false
                        }
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
                           activeReduxFocusedField: store.currentDocument?.graphUI.reduxFocusedField)
          

        }
    }
}
