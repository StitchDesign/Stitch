//
//  LogState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/12/22.
//

import Foundation
import StitchSchemaKit

struct LogExportState: Equatable {
    var preparingLogs = false
    var logsURL: LogEntriesURL?
}
