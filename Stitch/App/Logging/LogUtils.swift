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

/* ----------------------------------------------------------------
 Logging
 ---------------------------------------------------------------- */

enum LoggingAction: Equatable {
    case none, logToServer, fatal
}

// For debug printing from within SwiftUI views
func log(_ message: Any, _ loggingAction: LoggingAction = .none) {
    #if DEBUG || DEV_DEBUG
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

//        DispatchQueue.main.async {
//            dispatch(LogToServer(message: message))
//        }
    }
    #endif
}

func logInView(_ message: String) -> EmptyView {
    #if DEBUG || DEV_DEBUG
    print("** \(message)")
    #endif
    return EmptyView()
}
