//
//  NodeUIKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import Foundation
import StitchSchemaKit

enum NodeUIKind: Equatable, Hashable {
    case doubleSided, // most patch nodes
         inputsOnly, // prototypeRestart, all layer nodes, groupOutput
         outputsOnly // time, groupInput
}
