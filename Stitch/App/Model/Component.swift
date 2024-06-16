//
//  ComponentsState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/30/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

//// Note: keys need to be component-id, rather than underlying group-node's name, since two group-nodes may have same name.
typealias ComponentsDict = [UUID: StitchComponent]

// Note: our default projects will all have unique names
enum DefaultComponents: String, Equatable, CaseIterable {
    case curveShape = "Curve Shape"
    //    curveAlgorithm = "Curve Algorithm"
    //    pathBuilder = "Path Builder"
}
