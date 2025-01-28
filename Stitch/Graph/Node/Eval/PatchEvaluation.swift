//
//  PatchEvaluation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

struct EvalResult: NodeEvalResult, Sendable {
    var outputsValues: PortValuesList
    var runAgain = false

    // Determines if media objects changed in a manner which should trigger downstream nodes
    var didMediaObjectChange = false
    
    // Updates ephemeral observer if media changed
    var changedMedia: [StitchMediaObject?]? = nil
}

extension EvalResult {
    // TODO: clean up properties below?
    var willEvalAgain: Bool {
        get {
            self.runAgain
        }
        set(newValue) {
            self.runAgain = newValue
        }
    }
    
    var mustEvalAllDownstreamNodes: Bool {
        get {
            self.didMediaObjectChange
        }
        set(newValue) {
            self.didMediaObjectChange = newValue
        }
    }
    
    /// Failure state initializer.
    init() {
        self.outputsValues = []
    }
}
