//
//  AdjustmentBarHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias OnNewScrollCenter = @Sendable (CGPoint) -> Void

@MainActor
func readCenter(oldCenter: CGPoint?,
                currentCenter: CGPoint,
                onChange: @escaping OnNewScrollCenter) -> EmptyView {

    let noCenterYet = !oldCenter.isDefined
    let centerChanged = oldCenter.map({ $0 != currentCenter }) ?? false

    if noCenterYet || centerChanged {
        onChange(currentCenter)
    }
    return EmptyView()
}
