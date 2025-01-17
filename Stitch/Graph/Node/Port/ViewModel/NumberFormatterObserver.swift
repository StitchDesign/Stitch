//
//  NumberFormatterObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/30/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// A global number formatter, with fewer settings,
// seems to be fine perf-wise?
// (Tested on Mac Release Build.)
let GlobalFormatter = NumberFormatterObserver()

final class NumberFormatterObserver: NumberFormatter, @unchecked Sendable {
    override init() {
        super.init()
        self.maximumFractionDigits = 4
        self.minimumFractionDigits = 0
        self.minimumIntegerDigits = 1
    }

    required init?(coder: NSCoder) {
        log("NumberFormatterObserver.init(coder:) has not been implemented")
        super.init()
    }
}
