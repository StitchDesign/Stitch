//
//  AnimationEvaluationHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/19/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI

typealias OperationAnimation = (PortValues, ComputedNodeState) -> ImpureEvalOpResult
//
//// (updated output, updated animationState, runAgain?)
struct ImpureEvalOpResult {
    let outputs: PortValues
    var willRunAgain: Bool = false
}

extension ImpureEvalOpResult: NodeEvalOpResult {
    init(from values: PortValues) {
        self.outputs = values
    }
}
