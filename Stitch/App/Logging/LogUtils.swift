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
    // #if DEV_DEBUG
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

/// Conditional fatal error that can be disabled during eager AI parsing to prevent crashes from incomplete syntax
func fatalErrorIfDebugUnlessEagerParsing(_ message: String = "", file: String = #file, line: Int = #line) {
    if FeatureFlags.DO_NOT_CRASH_DURING_EAGER_PARSING {
        let fileName = (file as NSString).lastPathComponent
        log("🚨 Would crash during eager parsing (skipped): \(message) at \(fileName):\(line)")
        return
    }
    fatalErrorIfDebug(message)
}

/// Alternative for fatalErrorIfDevDebug that can be disabled during eager parsing
func fatalErrorIfDevDebugUnlessEagerParsing(_ message: String = "", file: String = #file, line: Int = #line) {
    if FeatureFlags.DO_NOT_CRASH_DURING_EAGER_PARSING {
        let fileName = (file as NSString).lastPathComponent
        log("🚨 Would crash during eager parsing (skipped): \(message) at \(fileName):\(line)")
        return
    }
    fatalErrorIfDevDebug(message)
}

/// Error thrown when eager parsing encounters a fatal error condition but doesn't want to crash
struct EagerParsingSkippedError: Error {
    let message: String
    let file: String
    let line: Int
}

/// Alternative for situations that would normally use fatalError() but should be skipped during eager parsing
/// Instead of returning Never, this throws an error that can be caught
func throwIfEagerParsingElseFatal(_ message: String = "", file: String = #file, line: Int = #line) throws {
    if FeatureFlags.DO_NOT_CRASH_DURING_EAGER_PARSING {
        let fileName = (file as NSString).lastPathComponent
        log("🚨 Would crash during eager parsing (skipped): \(message) at \(fileName):\(line)")
        throw EagerParsingSkippedError(message: message, file: fileName, line: line)
    }
    fatalError(message)
}

func assertInDebug(_ conditional: Bool) {
#if DEBUG || DEV_DEBUG || STITCH_AI_TESTING
    assert(conditional)
#endif
}

func assertInDebugIfNotEagerParsing(_ conditional: Bool) {
    if FeatureFlags.DO_NOT_CRASH_DURING_EAGER_PARSING {
        return
    }
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
//
//#if !RELEASE
//    print("** \(message)")
//
//    switch loggingAction {
//    case .none:
//        return
//    case .fatal:
//#if DEV_DEBUG
//        fatalError("FATAL: \(message)")
//#endif
//    case .logToServer:
//        print("WILL LOG TO SERVER: \(message)")
//        // Always send AI-related logs to Sentry regardless of build configuration
//        let messageString = String(describing: message)
//        SentrySDK.capture(message: messageString)
////        if messageString.contains("StitchAI") || messageString.contains("SupabaseManager") {
////            SentrySDK.capture(message: messageString)
////        }
//    }
//#else
//    // In production, send ALL logs to Sentry
//    if case .logToServer = loggingAction {
//        SentrySDK.capture(message: "\(message)")
//    }
//#endif
}

func logInView(_ message: String) -> EmptyView {
#if DEBUG || DEV_DEBUG || STITCH_AI_REASONING
    print("** \(message)")
#endif
    return EmptyView()
}
