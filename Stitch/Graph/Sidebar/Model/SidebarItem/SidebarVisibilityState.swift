//
//  SidebarVisibilityState.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias SidebarHiddenItems = LayerIdSet

struct PrimaryHiddenItems: Codable, Equatable, Hashable {
    var value = SidebarHiddenItems()
}

struct SecondaryHiddenItems: Codable, Equatable, Hashable {
    var value = SidebarHiddenItems()
}

// Persisted across project openings
struct SidebarVisibilityState: Codable, Equatable, Hashable {
    var primary = PrimaryHiddenItems()
    var secondary = SecondaryHiddenItems()
}

enum SidebarVisibilityStatus {
    case visible
    case hidden
    // Upstream group node is invisible
    case secondarilyHidden
}
