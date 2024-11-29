//
//  Redux.swift
//  Stitch
//
//  Created by cjc on 11/8/20.
//

import Combine
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 Adapting ReSwift for SwiftUI
 ---------------------------------------------------------------- */

typealias Dispatch = @MainActor (Action) -> Void

protocol Action: Sendable { }

typealias Actions = [Action]

// Can `Never` fail because failure will already have been handled
typealias Effect = @Sendable () async -> Action

typealias SideEffects = [Effect]

struct NoOp: Action { }
