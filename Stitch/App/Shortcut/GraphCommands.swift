//
//  GraphCommands.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/19/25.
//

import SwiftUI

struct GraphCommands: Commands {
    let store: StitchStore
    let textFieldFocused: Bool
    
    var activeProject: Bool {
        store.currentDocument != nil
    }
    
    var isSidebarFocused: Bool {
        store.currentDocument?.isSidebarFocused ?? false
    }
    
    var graph: GraphState? {
        self.store.currentDocument?.visibleGraph
    }
    
    var ungroupButtonEnabled: Bool {
        self.graph?.layersSidebarViewModel.canUngroup() ?? false
    }
    
    var groupButtonEnabled: Bool {
        self.graph?.layersSidebarViewModel.canBeGrouped() ?? false
    }
    
    var body: some Commands {
        CommandMenu("Graph") {
            SwiftUIShortcutView(title: "Insert...",
                                key: .return,
                                disabled: !activeProject) {
                INSERT_NODE_ACTION()
            }
                        
            if let document = store.currentDocument {
                InsertNodeCommands(store: store,
                                   document: document)
            }
            
            Divider()
            
            SwiftUIShortcutView(title: "Select All",
                                key: SELECT_ALL_NODES_SHORTCUT,
                                // Disable CMD+A "select all" when an input text field is focused
                                disabled: textFieldFocused || !activeProject) {
                dispatch(SelectAllShortcutKeyPressed())
            }
            
            Divider()
            
            SwiftUIShortcutView(title: "Group",
                                key: CREATE_GROUP_SHORTCUT,
                                disabled: !activeProject) {
                let cannotCreateLayerGroup = !isSidebarFocused || !groupButtonEnabled
                
                if cannotCreateLayerGroup {
                    dispatch(GroupNodeCreated(isComponent: false))
                } else {
                    self.graph?.layersSidebarViewModel.sidebarGroupCreated()
                }
            }
            
            SwiftUIShortcutView(title: "Ungroup",
                                key: DELETE_SELECTED_NODES_SHORTCUT,
                                eventModifiers: [.command],
                                disabled: !activeProject) {
                
                let cannotUngroupLayer = !isSidebarFocused || !ungroupButtonEnabled
                
                if cannotUngroupLayer {
                    dispatch(SelectedGroupNodesUncreated())
                } else {
                    self.graph?.layersSidebarViewModel.sidebarGroupUncreated()
                }
            }
        }
    }
}
