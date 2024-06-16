//
//  DeriveSidebarList.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/14/24.
//

import Foundation

// TODO: this is a 'cover-all' for cases where we reactively update sidebar-ui-state after e.g. a  node count change.
// Alternatively we could find all the actions that cause such a change, or locate this logic in the redux middleware itself.
// What we're really struggling with is handling derived data
struct DeriveSidebarList: GraphEvent {
    
    func handle(state: GraphState) {
        state.updateSidebarListStateAfterStateChange()
    }
}
