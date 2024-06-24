//
//  LogHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/9/22.
//

import Foundation
import StitchSchemaKit
import OSLog
import UIKit

// 15 = 15 minutes
// 60 = 60 minutes
let OSLOGS_FROM_WITHIN_THE_LAST_N_MINUTES: Double = 10

// Takes a while to run -- best handled in a side-effect
// MARK: this is unused
func getLogEntries(scope: OSLogStore.Scope = .currentProcessIdentifier,
                   inLastNMinutes: Double = OSLOGS_FROM_WITHIN_THE_LAST_N_MINUTES,
                   subsystem: String = STITCH_OSLOG_SUBSYSTEM,
                   sender: String = STITCH_OSLOG_SENDER) -> LogEntriesResult {

    // Open the log store.
    guard let logStore = try? OSLogStore(scope: scope) else {
        log("getLogEntries: could not rerieve logStore for scope \(scope)")
        return .failure(.logsFailed(logError: .osLogStoreAccess))
    }

    // "within the last hour" if `inLastNMinutes` == 60
    let logTimeWithin = logStore.position(date: Date().addingTimeInterval(-1 * 60 * inLastNMinutes))

    // Fetch log objects.
    guard let allEntries = try? logStore.getEntries(at: logTimeWithin) else {
        log("getLogEntries: could not rerieve entries for at time \(logTimeWithin)")
        return .failure(.logsFailed(logError: .osLogStoreAccess))
    }

    // Filter the log to be relevant for our specific subsystem
    // and remove other elements (signposts, etc).
    let entries = allEntries
        .compactMap { $0 as? OSLogEntryLog }

        // better?: filterat the `logStore.getEntries` call via the predicate API
        .filter { (entry: OSLogEntryLog) in
            entry.sender == STITCH_OSLOG_SENDER
                && entry.subsystem == STITCH_OSLOG_SUBSYSTEM
        }

    return .success(entries)
}

/// Saves user's console logs to a temp file.
func saveConsoleLogs(in directory: URL, logListener: LogListener) async -> URLResult {
    let logsString = logListener.contents

    let fileURL = directory
        .appendingPathComponent("console-logs")
        .appendingPathExtension("txt")

    do {
        try logsString.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
        log("saveConsoleLogs error: \(error)")
        return .failure(.logsFailed(logError: .consoleLogsSaveFailed))
    }

    return .success(fileURL)
}

// TODO: What specifically in the logs do we want to look at?
// MARK: we aren't using this right now
func formatLogEntry(_ message: OSLogEntryLog) -> String {
    """
    \n\nLOG
    composedMessage: \(message.composedMessage)
    date: \(message.date)
    level: \(message.level)
    process: \(message.process)
    sender: \(message.sender)
    processIdentifier: \(message.processIdentifier)
    activityIdentifier: \(message.activityIdentifier)
    """
}

struct LogEntriesURL: Equatable {
    let url: URL
}

enum LogEntriesRetrievalFailure: String, Error, Equatable {
    case osLogStoreAccess,          // failed to access OSLog store
         osLogWrite,                // failed to write the logs to a file
         osLogFile,                 // could not access written-logs file
         consoleLogsSaveFailed      // failed to get console logs
}

func createOSLogFile(in directory: URL) -> URL {
    directory
        .appendingPathComponent("os-logs")
        .appendingPathExtension("txt")
}

// Need some way to identify the project,
// MARK: this is currently unused.
func writeOSLogEntries(in osLogURL: URL, _ entries: LogEntries) -> Result<LogEntriesURL, LogEntriesRetrievalFailure> {

    // One long string
    let contents = entries.reduce("") { $0 + formatLogEntry($1) }

    do {
        try contents.write(to: osLogURL, atomically: true, encoding: .utf8)
        return .success(LogEntriesURL(url: osLogURL))
    } catch {
        // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        return .failure(.osLogWrite)
    }
}

@MainActor
func writeDeviceInfo(to url: URL) -> StitchFileVoidResult {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let deviceModelName = UIDevice.modelName
    let systemVersion = UIDevice.current.systemVersion

    let deviceInfo = """
DEVICE INFO
App Version:\t\(appVersion)
Device Model:\t\(deviceModelName)
OS Version:\t\(systemVersion)
"""

    do {
        try deviceInfo.write(to: url, atomically: true, encoding: .utf8)
        return .success
    } catch {
        log("writeDeviceInfo error: failed to write info with error: \(error)")
        return .failure(.logsFailed(logError: .osLogFile))
    }
}

/// Creates the name of the file zip destination, which uses the current date and time.
func createLogLocationName() -> String {
    // Create zip of directory
    let dateTime = Date().ISO8601Format(.init(dateSeparator: .dash,
                                              dateTimeSeparator: .standard,
                                              timeSeparator: .colon,
                                              timeZoneSeparator: .omitted,
                                              includingFractionalSeconds: false))
    return "stitch-logs-\(dateTime)"
}

extension StitchFileManager {
    func createLogsZip(directory: URL) -> URLResult {
        let zipName = directory.lastPathComponent

        let zipLocation = Self.tempDir
            .appendingPathComponent(zipName)
            .appendingPathExtension("zip")

        switch self.zip(from: directory, to: zipLocation) {
        case .success:
            // Remove old directory
            try? self.removeItem(at: directory)

            return .success(zipLocation)
        case .failure(let error):
            return .failure(error)
        }
    }
}
