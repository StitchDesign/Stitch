//
//  PreviewCommonPositionModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PreviewCommonPositionModifier: ViewModifier {
    
    // Is this view a child of a group that uses HStack or VStack? If so, we ignore this view's position.
    let parentDisablesPosition: Bool

    // Position already adjusted by anchoring
    var pos: StitchPosition
    
    func body(content: Content) -> some View {
        if parentDisablesPosition {
            content
        } else {
            content
                .position(x: pos.width, y: pos.height)
        }
    }
}
