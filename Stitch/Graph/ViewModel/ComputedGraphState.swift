//
//  ComputedGraphState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/16/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct NetworkRequestTimeCoordinate: Equatable, Hashable {
    let nodeId: NodeId
    let index: Int
}

typealias NetworkRequestLatestCompletedTimeDict = [NetworkRequestTimeCoordinate: TimeInterval]

// TODO: move `ComputedGraphState`
@Observable
final class ComputedGraphState {
    var networkRequestCompletedTimes = NetworkRequestLatestCompletedTimeDict()
}
