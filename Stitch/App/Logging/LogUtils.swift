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
        print("WILL LOG TO SERVER: \(message)")
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

// MARK: - AI Request Debug File Writing

/// Writes comprehensive debug information for AI requests to a file on the user's desktop
func writeAIRequestDebugFile(
    userPrompt: String,
    requestId: UUID,
    initialSwiftUICode: String,
    generatedSwiftUICode: String,
    derivedLayerData: String,
    systemPrompt: String
) {
    #if DEBUG || DEV_DEBUG
    do {
        // Try Desktop first, fall back to Documents, then temp directory
        let possibleDirectories: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .documentDirectory
        ]
        
        var targetURL: URL?
        for directory in possibleDirectories {
            if let url = FileManager.default.urls(for: directory, in: .userDomainMask).first,
               FileManager.default.isWritableFile(atPath: url.path) {
                targetURL = url
                break
            }
        }
        
        // If no writable directory found, use temp directory
        if targetURL == nil {
            targetURL = FileManager.default.temporaryDirectory
        }
        
        guard let baseURL = targetURL else {
            print("** Warning: No writable directory found for AI debug file")
            return
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Create safe filename from user prompt
        let safePrompt = sanitizeFilename(userPrompt)
        let truncatedPrompt = String(safePrompt.prefix(50)) // Limit to 50 characters
        let filename = "AI_Debug_\(truncatedPrompt)_\(timestamp).txt"
        let fileURL = baseURL.appendingPathComponent(filename)
        
        // Format content matching the provided example
        let content = """
** SUCCESS: userPrompt: \(userPrompt)
** Request ID: \(requestId.uuidString)
** Timestamp: \(timestamp)
** AICodeGenFromGraphRequest.createCode initial code:
\(initialSwiftUICode)

** StitchAICodeCreator swiftUICode:
\(generatedSwiftUICode)

** Derived Stitch layer data:
\(derivedLayerData)

** System Prompt:
\(systemPrompt)
"""
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("** AI Debug file written to: \(fileURL.path)")
        
        // Also print the directory type for clarity
        let directoryName = fileURL.deletingLastPathComponent().lastPathComponent
        print("** Debug file location: \(directoryName) directory")
        
    } catch {
        // Don't let debug file writing break the main flow
        print("** Warning: Failed to write AI debug file: \(error)")
    }
    #endif
}

/// Sanitizes a string to be safe for use as a filename
private func sanitizeFilename(_ input: String) -> String {
    let invalidCharacters = CharacterSet(charactersIn: ":/\\?*|\"<>")
    return input.components(separatedBy: invalidCharacters).joined(separator: "_")
}
