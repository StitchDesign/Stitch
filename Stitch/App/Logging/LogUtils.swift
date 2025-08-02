//
//  LogUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/1/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OSLog
import Sentry

struct FatalErrorIfDebugView: View {
    var body: some View {
        Color.clear
            .onAppear {
                fatalErrorIfDebug()
            }
    }
}

func logToServerIfRelease(_ message: String) {
    #if RELEASE
    log(message, .logToServer)
    #else
    log(message)
    #endif
}

func fatalErrorIfDebug(_ message: String = "") {
#if DEBUG || DEV_DEBUG || STITCH_AI_TESTING
    fatalError(message)
#else
    // When we encounter a "crash if developing locally" while we're running on production,
    // we should log to Sentry.
    log(message, .logToServer)
#endif
}

func fatalErrorIfDevDebug(_ message: String = "") {
#if DEV_DEBUG
    fatalError(message)
#else
    // When we encounter a "crash if developing locally" while we're running on production,
    // we should log to Sentry.
    log(message, .logToServer)
#endif
}

func assertInDebug(_ conditional: Bool) {
#if DEBUG || DEV_DEBUG || STITCH_AI_TESTING
    assert(conditional)
#endif
}

/* ----------------------------------------------------------------
 Logging
 ---------------------------------------------------------------- */

enum LoggingAction: Equatable {
    case none, logToServer, fatal
}

// For debug printing from within SwiftUI views
func log(_ message: Any,
         _ loggingAction: LoggingAction = .none) {
#if !RELEASE
    print("** \(message)")

    switch loggingAction {
    case .none:
        return
    case .fatal:
#if DEV_DEBUG
        fatalError("FATAL: \(message)")
#endif
    case .logToServer:
        print("HAD MAJOR ERROR: \(message)")
        // Always send AI-related logs to Sentry regardless of build configuration
        let messageString = String(describing: message)
        SentrySDK.capture(message: messageString)
//        if messageString.contains("StitchAI") || messageString.contains("SupabaseManager") {
//            SentrySDK.capture(message: messageString)
//        }
    }
#else
    // In production, send ALL logs to Sentry
    if case .logToServer = loggingAction {
        SentrySDK.capture(message: "\(message)")
    }
#endif
}

func logInView(_ message: String) -> EmptyView {
#if DEBUG || DEV_DEBUG || STITCH_AI_REASONING
    print("** \(message)")
#endif
    return EmptyView()
}
