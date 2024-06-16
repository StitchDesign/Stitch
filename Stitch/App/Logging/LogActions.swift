//
//  LogActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/9/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OSLog

typealias LogEntry = OSLogEntryLog
typealias LogEntries = [LogEntry]

struct LogsExportStarted: AppEvent {

    func handle(state: AppState) -> AppResponse {

        var state = state
        state.alertState.logExport.preparingLogs = true

        let effect = { @Sendable in
            CreateLogEntries()
        }

        return .init(effects: [effect], state: state)
    }
}

struct CreateLogEntries: LogEvent, Sendable {
    func handle(logListener: LogListener, fileManager: StitchFileManager) -> MiddlewareManagerResponse {
        // Directory to host both logging files
        let logLocationName = createLogLocationName()
        let directory = StitchFileManager.tempDir.appendingPathComponent(logLocationName)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let effect: Effect = {
            // Save console logs to temp file
            switch await saveConsoleLogs(in: directory, logListener: logListener) {
            case .success:
                let osLogURL = createOSLogFile(in: directory)

                // Retrieve OS logs and then present sharing options to user
                switch await writeDeviceInfo(to: osLogURL) {
                case .success:
                    // Create zip of both logs
                    switch fileManager.createLogsZip(directory: directory) {
                    case .success(let logsZip):
                        return LogsEntriesRetrieved(logsZip: logsZip)
                    case .failure(let error):
                        return ReceivedStitchFileError(error: error)
                    }
                case .failure(let error):
                    return ReceivedStitchFileError(error: error)
                }
            case .failure(let error):
                return ReceivedStitchFileError(error: error)
            }
        }

        return .effectOnly(effect)
    }
}

/// Action to ready created logs zip in share sheet.
struct LogsEntriesRetrieved: AppEvent {

    let logsZip: URL

    func handle(state: AppState) -> AppResponse {
        print("LogsEntriesRetrieved")
        var state = state

        // We're done preparing logs
        state.alertState.logExport.preparingLogs = false
        state.alertState.logExport.logsURL = LogEntriesURL(url: logsZip)

        return .stateOnly(state)
    }
}

struct HideLogPreparationSheet: AppEvent {
    func handle(state: AppState) -> ReframeResponse<AppState> {
        var state = state
        state.alertState.logExport.preparingLogs = false
        return .stateOnly(state)
    }
}

struct LogsSuccessfullyExported: AppEvent {

    func handle(state: AppState) -> ReframeResponse<AppState> {
        var state = state
        state.alertState.logExport.logsURL = nil
        return .stateOnly(state)
    }
}
