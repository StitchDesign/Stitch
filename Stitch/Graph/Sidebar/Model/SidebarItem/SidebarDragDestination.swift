//
//  SidebarDragDestination.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI

/// Helps us determine if we place items after a certain element or at the top of some group.
enum SidebarDragDestination<Element: Identifiable> {
    case afterElement(Element)
    case topOfGroup(Element?)    // root if nil
}

extension SidebarDragDestination {
    var element: Element? {
        switch self {
        case .afterElement(let element): return element
        case .topOfGroup(let element): return element
        }
    }
    
    var id: Element.ID? {
        switch self {
        case .afterElement(let element): return element.id
        case .topOfGroup(let element): return element?.id
        }
    }
    
    var isAfter: Bool {
        if case .afterElement = self { return true }
        return false
    }
}
