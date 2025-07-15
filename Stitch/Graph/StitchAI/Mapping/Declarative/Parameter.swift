//
//  Parameter.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser

struct ASTCustomInputValue: Equatable, Hashable {
    let input: CurrentStep.LayerInputPort
    let value: CurrentStep.PortValue
}
