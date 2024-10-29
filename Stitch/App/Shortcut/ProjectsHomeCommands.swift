//
//  ProjectsHomeCommands.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/1/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ProjectsHomeCommands: Commands {

    @Bindable var store: StitchStore
    @FocusedValue(\.focusedField) private var focusedField

    let activeReduxFocusedField: FocusedUserEditField?

    var activeProject: Bool {
        store.currentDocument.isDefined
    }
        
    var isSidebarFocused: Bool {
        self.graph?.graphUI.isSidebarFocused ?? false
    }
    
    var graph: GraphState? {
        store.currentDocument?.visibleGraph
    }
    
    var ungroupButtonEnabled: Bool {
        self.graph?.layersSidebarViewModel.canUngroup() ?? false
    }

    var groupButtonEnabled: Bool {
        self.graph?.layersSidebarViewModel.canBeGrouped() ?? false
    }
    
    var textFieldFocused: Bool {
        let k = activeReduxFocusedField.isDefined || focusedField.isDefined
        //        log("ProjectsHomeCommands: activeReduxFocusedField: \(activeReduxFocusedField)")
        //        log("ProjectsHomeCommands: focusedField.isDefined: \(focusedField.isDefined)")
        //        log("ProjectsHomeCommands: k: \(k)")
        return k
    }

    var body: some Commands {

        CommandMenu("Graph") {

            // NOTE: `title:` but not `key:` can be replaced by runtime state changes.
            SwiftUIShortcutView(title: activeProject ? "Restart Prototype" : "Refresh Projects",
                                key: .init("R")) {
                if activeProject {
                    dispatch(PrototypeRestartedAction())
                } else {
                    store.allProjectUrls = []
                    dispatch(DirectoryUpdated())
                }
            }

            if activeProject {

                Divider()

//                SwiftUIShortcutView(title: "Insert Node",
                SwiftUIShortcutView(title: "Insert",
                                    key: .return) {
                    INSERT_NODE_ACTION()
                }

//                SwiftUIShortcutView(title: "Duplicate Node(s)",
                SwiftUIShortcutView(title: "Duplicate",
                                    key: DUPLICATE_SELECTED_NODES_SHORTCUT) {
                    // duplicates both selected nodes and selected comments
                    dispatch(DuplicateShortcutKeyPressed())
                }

//                SwiftUIShortcutView(title: "Delete Node(s)",
                SwiftUIShortcutView(title: "Delete",
                                    key: DELETE_SELECTED_NODES_SHORTCUT,
                                    // empty list = do not require CMD
                                    eventModifiers: DELETE_SELECTED_NODES_SHORTCUT_MODIFIERS) {
                    // deletes both selected nodes and selected comments
                    dispatch(DeleteShortcutKeyPressed())
                }

                // Not shown in menu when no active project;
                // Disabled when we have focused text input
                //            if activeProject {
//                SwiftUIShortcutView(title: "Cut Node(s)",
                SwiftUIShortcutView(title: "Cut",
                                    key: CUT_SELECTED_NODES_SHORTCUT,
                                    disabled: textFieldFocused) {
                    log("cut shortcut")
                    //                    dispatch(SelectedGraphNodesCut())

                    // cuts both nodes and comments
                    dispatch(SelectedGraphItemsCut())
                }

//                SwiftUIShortcutView(title: "Copy Node(s)",
                SwiftUIShortcutView(title: "Copy",
                                    key: COPY_SELECTED_NODES_SHORTCUT,
                                    disabled: textFieldFocused) {
                    log("copy shortcut")
                    //                    dispatch(SelectedGraphNodesCopied())
                    
                    // copies both nodes and comments
                    dispatch(SelectedGraphItemsCopied())
                }
                
//                SwiftUIShortcutView(title: "Paste Node(s)",
                SwiftUIShortcutView(title: "Paste",
                                    key: PASTE_SELECTED_NODES_SHORTCUT,
                                    disabled: textFieldFocused) {
                    log("paste shortcut")
                    //                    dispatch(SelectedGraphNodesPasted())
                    
                    // pastes both nodes and comments
                    dispatch(SelectedGraphItemsPasted())
                }
                
                SwiftUIShortcutView(title: "Insert Unpack Node",
                                    key: ADD_UNPACK_NODE_SHORTCUT,
                                    // empty list = do not require CMD
                                    eventModifiers: CMD_MODIFIER,
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.sizeUnpack)))
                }
                
                SwiftUIShortcutView(title: "Insert Pack Node",
                                    key: ADD_PACK_NODE_SHORTCUT,
                                    // empty list = do not require CMD
                                    eventModifiers: CMD_MODIFIER,
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.sizePack)))
                }
                
                SwiftUIShortcutView(title: "Insert Value Node",
                                    key: ADD_SPLITTER_NODE_SHORTCUT,
                                    // empty list = do not require CMD
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.splitter)))
                }
                
                // Option + W = add Broadcaster
                SwiftUIShortcutView(title: "Insert Wireless Broadcaster",
                                    key: ADD_WIRELESS_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.wirelessBroadcaster)))
                    // TODO: probably not needed?
                    store.currentDocument?.keypressState.modifiers.remove(.option)
                }
                
                // Option + Shift + W = add Receiver
                SwiftUIShortcutView(title: "Insert Wireless Receiver",
                                    key: ADD_WIRELESS_NODE_SHORTCUT,
                                    eventModifiers: [.option, .shift],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.wirelessReceiver)))
                    // Note: the Option key seems to get stuck easily when Shift is also pressed?
                    store.currentDocument?.keypressState.modifiers.remove(.option)
                    store.currentDocument?.keypressState.modifiers.remove(.shift)
                }
            } // if activeProject

        } // CommandMenu

        CommandGroup(replacing: .newItem) {
            SwiftUIShortcutView(title: activeProject ? "New Node" : "New Project",
                                key: NEW_PROJECT_SHORTCUT) {
                if activeProject {
                    INSERT_NODE_ACTION()
                } else {
                    store.createNewProject()
                }
            }

            // NOTE: we already get CMD + W in Catalyst
            // TODO: only show with active project
            #if !targetEnvironment(macCatalyst)
            if store.currentDocument != nil {
                SwiftUIShortcutView(title: "Close Graph",
                                    key: CLOSE_GRAPH_SHORTCUT) {
                    dispatch(CloseGraph())
                }
            }
            #endif
        }

        CommandGroup(replacing: .importExport) {
            if activeProject {
                SwiftUIShortcutView(title: "Add File to Project",
                                    key: "O", // the letter O
                                    eventModifiers: [.command],
                                    disabled: !activeProject) {
                    FILE_IMPORT_ACTION()
                }
            }

            SwiftUIShortcutView(title: "Delete All Projects",
                                key: .delete,
                                eventModifiers: [.command, .shift],
                                // only relevant on projects homescreen
                                disabled: activeProject) {
                DELETE_ALL_PROJECTS_ALERT_ACTION()
            }
        }

        CommandGroup(before: .sidebar) {
            if activeProject {
                SwiftUIShortcutView(title: "Toggle Preview Window",
                                    key: "/",
                                    eventModifiers: .command,
                                    disabled: !activeProject) {
                    PREVIEW_SHOW_TOGGLE_ACTION()
                }
                                    
            }
            
            if activeProject {
                SwiftUIShortcutView(title: "Toggle Sidebars",
                                    key: ".",
                                    eventModifiers: .command,
                                    disabled: !activeProject) {
                    dispatch(ToggleSidebars())
                }
                                    
            }

            if activeProject {
                SwiftUIShortcutView(title: "Full Screen Preview Window",
                                    key: "F",
                                    eventModifiers: [.command, .shift],
                                    disabled: !activeProject) {
                    PREVIEW_FULL_SCREEN_ACTION()
                }
            }
        }

        // TODO: should be toggle? e.g. pressing `CMD + ,` again should close app / project settings window?
        CommandGroup(replacing: CommandGroupPlacement.appSettings) {
            SwiftUIShortcutView(title: "Settings",
                                key: ",",
                                eventModifiers: .command) {
                if activeProject {
                    PROJECT_SETTINGS_ACTION()
                } else {
                    SHOW_APP_SETTINGS()
                }
            }
        }

        CommandGroup(replacing: .undoRedo) {
            SwiftUIShortcutView(title: "Undo",
                                key: UNDO_SHORTCUT,
                                eventModifiers: CMD_MODIFIER,
                                disabled: textFieldFocused) {
                dispatch(UndoEvent())
            }

            SwiftUIShortcutView(title: "Redo",
                                key: UNDO_SHORTCUT,
                                eventModifiers: [.command, .shift],
                                disabled: textFieldFocused) {
                dispatch(RedoEvent())
            }
        } // replacing: .undoRedo

        
        // Don't show any of these if we're on projects-home-screen
        if activeProject {

            // TODO: These commands should only apppear with graph
            CommandGroup(replacing: .pasteboard) {
                SwiftUIShortcutView(title: "Select All",
                                    key: SELECT_ALL_NODES_SHORTCUT,
                                    // Disable CMD+A "select all" when an input text field is focused
                                    disabled: textFieldFocused || !activeProject) {
                    //                    dispatch(ToggleSelectAllNodes())
                    dispatch(SelectAllShortcutKeyPressed())
                }
                
                SwiftUIShortcutView(title: "Group Layers",
                                    key: GROUP_LAYERS_SHORTCUT,
                                    // Disabled if no layers are actively selected
                                    disabled: !isSidebarFocused || !groupButtonEnabled) {
                    // deletes both selected nodes and selected comments
                    self.graph?.layersSidebarViewModel.sidebarGroupCreated()
                }
                
                SwiftUIShortcutView(title: "Ungroup Layers",
                                    key: DELETE_SELECTED_NODES_SHORTCUT,
                                    eventModifiers: [.command],
                                    // Disabled if no layers are actively selected
                                    disabled: !isSidebarFocused || !ungroupButtonEnabled) {
//                                    disabled: !isSidebarFocused) {
                    // deletes both selected nodes and selected comments
                    self.graph?.layersSidebarViewModel.sidebarGroupUncreated()
                }
                
            } // replacing: .pasteboard
            
        } // if activeProject
    }
}
