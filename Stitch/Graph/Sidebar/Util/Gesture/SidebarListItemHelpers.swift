//
//  SidebarListItemHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/27/24.
//

import Foundation
import SwiftUI

extension SidebarItemSwipable {
    func isSelected(_ selections: Set<Self.ID>) -> Bool {
        selections.contains(self.id)
    }
    
    func implicitlyDragged(_ implicitlyDraggedItems: Set<Self.ID>) -> Bool {
        implicitlyDraggedItems.contains(self.id)
    }
}
