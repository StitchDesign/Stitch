//
//  GroupCandidate.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/26/25.
//

import SwiftUI

enum GroupCandidate<Element: SidebarItemSwipable> {
    // Nil for root case
    case valid(Element.ID?)
    case invalid
}

extension GroupCandidate {
    var isValidGroup: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    public var parentId: Element.ID? {
        switch self {
        case .valid(let id):
            return id
        case .invalid:
            return nil
        }
    }
}

