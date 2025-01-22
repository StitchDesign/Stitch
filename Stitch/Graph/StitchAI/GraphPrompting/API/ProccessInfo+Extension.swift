//
//  ProccessInfo+Extension.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/21/25.
//

import Foundation

extension ProcessInfo {
    var isRunningInXcodeCloud: Bool {
        return environment["CI"] == "true"
    }
}
