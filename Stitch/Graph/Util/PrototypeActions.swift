//
//  StitchActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PrototypeRestartedAction: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        log("PrototypeRestartedAction called")
        state.onPrototypeRestart(document: state)
    }
}
