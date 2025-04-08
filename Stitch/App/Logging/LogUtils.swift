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

func fatalErrorIfDebug(_ message: String = "") {
#if DEBUG || DEV_DEBUG || STITCH_AI
    fatalError(message)
#else
    log(message)
#endif
}

// Crash helpers intended only for local developer use
func fatalErrorIfDebugOnly(_ message: String = "") {
#if DEBUG || DEV_DEBUG
    fatalError(message)
#else
    log(message)
#endif
}


func assertInDebug(_ conditional: Bool) {
#if DEBUG || DEV_DEBUG || STITCH_AI
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
func log(_ message: Any, _ loggingAction: LoggingAction = .none) {
    #if DEBUG || DEV_DEBUG || STITCH_AI
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
        if messageString.contains("StitchAI") || messageString.contains("SupabaseManager") {
            SentrySDK.capture(message: messageString)
        }
    }
    #else
    // In production, send ALL logs to Sentry
    if case .logToServer = loggingAction {
        SentrySDK.capture(message: "\(message)")
    }
    #endif
}

func logInView(_ message: String) -> EmptyView {
    #if DEBUG || DEV_DEBUG || STITCH_AI
    print("** \(message)")
    #endif
    return EmptyView()
}
