//
//  StitchLogger.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/9/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OSLog

let STITCH_OSLOG_SENDER = "Stitch"
let STITCH_OSLOG_SUBSYSTEM = STITCH_OSLOG_SENDER
let STITCH_OSLOG_CATEGORY = "APP_DEBUG"

/// Class which listens to STDOUT. Used for enabling users to share console logs, which are hard to retrieve without a fatal error.
/// Source: https://phatbl.at/2019/01/08/intercepting-stdout-in-swift.html
final class LogListener {

    /// Consumes the messages on STDOUT
    let inputPipe = Pipe()

    /// Outputs messages back to STDOUT
    let outputPipe = Pipe()

    /// Used for OS-level logging
    // MARK: this is currently unused.
    private let osLogger = Logger(subsystem: STITCH_OSLOG_SUBSYSTEM,
                                  category: STITCH_OSLOG_CATEGORY)

    /// Buffers strings written to stdout
    var contents = ""

    var stdoutFileDescriptor: Int32 { FileHandle.standardOutput.fileDescriptor }

    init() {
        #if !DEV_DEBUG
        // Set up a read handler which fires when data is written to our inputPipe
        inputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            guard let strongSelf = self else { return }

            let data = fileHandle.availableData
            if let string = String(data: data, encoding: String.Encoding.utf8) {
                strongSelf.contents += string
            }

            // Write input back to stdout
            strongSelf.outputPipe.fileHandleForWriting.write(data)
        }

        self.openConsolePipe()
        #endif
    }

    /// Sets up the "tee" of piped output, intercepting stdout then passing it through.
    func openConsolePipe() {
        // Copy STDOUT file descriptor to outputPipe for writing strings back to STDOUT
        dup2(stdoutFileDescriptor, outputPipe.fileHandleForWriting.fileDescriptor)

        // Intercept STDOUT with inputPipe
        dup2(inputPipe.fileHandleForWriting.fileDescriptor, stdoutFileDescriptor)
    }

    /// Tears down the "tee" of piped output.
    func closeConsolePipe() {
        // Restore stdout
        freopen("/dev/stdout", "a", stdout)

        [inputPipe.fileHandleForReading, outputPipe.fileHandleForWriting].forEach { file in
            file.closeFile()
        }
    }

    /// Fires off OS-level logs.
    // MARK: this is current unused.
    //    func osLog(_ message: String,
    //               level: OSLogType = .info) {
    //        osLogger.log(level: level, "\(message)")
    //    }

    deinit {
        #if !DEV_DEBUG
        self.closeConsolePipe()
        #endif
    }
}
