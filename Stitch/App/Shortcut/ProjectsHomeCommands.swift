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
    @Environment(\.openURL) private var openURL
    
    @Bindable var store: StitchStore
    @FocusedValue(\.focusedField) private var focusedField

    let activeReduxFocusedField: FocusedUserEditField?

    var activeProject: Bool {
        store.currentDocument.isDefined
    }
        
    var isSidebarFocused: Bool {
        store.currentDocument?.visibleGraph.layersSidebarViewModel.isSidebarFocused ?? false
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
        activeReduxFocusedField.isDefined || focusedField.isDefined
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
                
                SwiftUIShortcutView(title: "Insert",
                                    key: .return) {
                    INSERT_NODE_ACTION()
                }
                
                SwiftUIShortcutView(title: "Duplicate",
                                    key: DUPLICATE_SELECTED_NODES_SHORTCUT) {
                    dispatch(DuplicateShortcutKeyPressed())
                }
                
                // TODO: should CMD+Delete ungroup a GroupNode on the canvas, as it ungroups a LayerGroup in the sidebar?
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
                SwiftUIShortcutView(title: "Cut",
                                    key: CUT_SELECTED_NODES_SHORTCUT,
                                    disabled: textFieldFocused) {
                    log("cut shortcut")
                    // cuts both nodes and comments
                    dispatch(SelectedGraphItemsCut())
                }
                
                SwiftUIShortcutView(title: "Copy",
                                    key: COPY_SELECTED_NODES_SHORTCUT,
                                    disabled: textFieldFocused) {
                    log("copy shortcut")
                    // copies both nodes and comments
                    dispatch(SelectedGraphItemsCopied())
                }
                
                SwiftUIShortcutView(title: "Paste",
                                    key: PASTE_SELECTED_NODES_SHORTCUT,
                                    disabled: textFieldFocused) {
                    log("paste shortcut")
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
                
                // TODO: maybe it would be better if these options did not all show up in the Graph menu on Catalyst?
                SwiftUIShortcutView(title: "Insert Add Node",
                                    key: ADD_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.add)))
                }
                
                SwiftUIShortcutView(title: "Insert Subtract Node",
                                    key: SUBTRACT_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.subtract)))
                }
                
                SwiftUIShortcutView(title: "Insert Multiply Node",
                                    key: MULTIPLY_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.multiply)))
                }
                
                SwiftUIShortcutView(title: "Insert Divide Node",
                                    key: DIVIDE_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.divide)))
                }
                
                SwiftUIShortcutView(title: "Insert Power Node",
                                    key: POWER_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.power)))
                }
                
                SwiftUIShortcutView(title: "Insert Mod Node",
                                    key: MOD_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.mod)))
                }
                
                SwiftUIShortcutView(title: "Insert Less Than Node",
                                    key: LESS_THAN_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.lessThan)))
                }
                
                SwiftUIShortcutView(title: "Insert Greater Than Node",
                                    key: GREATER_THAN_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.greaterThan)))
                }
                
                SwiftUIShortcutView(title: "Insert Classic Animation Node",
                                    key: CLASSIC_ANIMATION_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.classicAnimation)))
                }
                
                SwiftUIShortcutView(title: "Insert Pop Animation Node",
                                    key: POP_ANIMATION_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.popAnimation)))
                }
                
                SwiftUIShortcutView(title: "Insert Switch Node",
                                    key: SWITCH_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.flipSwitch)))
                }
                
                SwiftUIShortcutView(title: "Insert Delay Node",
                                    key: DELAY_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.delay)))
                }
                
                SwiftUIShortcutView(title: "Insert Keyboard Node",
                                    key: KEYBOARD_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.keyboard)))
                }
                
                // NO LONGER SUPPORTED NOW THAT WE PREFER LAYER GROUPS FOR SCROLLING
//                SwiftUIShortcutView(title: "Insert Scroll Node",
//                                    key: SCROLL_NODE_SHORTCUT,
//                                    eventModifiers: [.option],
//                                    disabled: textFieldFocused) {
//                    dispatch(NodeCreatedEvent(choice: .patch(.scrollInteraction)))
//                }
                
                SwiftUIShortcutView(title: "Insert Equals Node",
                                    key: EQUALS_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.equals)))
                }
                
                SwiftUIShortcutView(title: "Insert Reverse Progress Node",
                                    key: REVERSE_PROGRESS_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.reverseProgress)))
                }
                
                SwiftUIShortcutView(title: "Insert Transition Node",
                                    key: TRANSITION_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.transition)))
                }
                
                SwiftUIShortcutView(title: "Insert Pulse Node",
                                    key: PULSE_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.pulse)))
                }
                
                SwiftUIShortcutView(title: "Insert Press Interaction Node",
                                    key: PRESS_INTERACTION_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.pressInteraction)))
                }
                
                SwiftUIShortcutView(title: "Insert Option Picker Node",
                                    key: OPTION_PICKER_NODE_SHORTCUT,
                                    eventModifiers: [.option],
                                    disabled: textFieldFocused) {
                    dispatch(NodeCreatedEvent(choice: .patch(.optionPicker)))
                }
            } // if activeProject

        } // CommandMenu
        
        CommandGroup(after: .appInfo) {
            Menu {
                // Opens the user’s default mail client with a pre-filled address
                Button {
                    if let url = URL(string: "mailto:hello@stitchdesign.app") {
                        openURL(url)
                    }
                } label: {
                    Text("Email")
                }
                
                // Launches the system browser and navigates to your site
                Button {
                    if let url = URL(string: "https://github.com/StitchDesign/Stitch/issues/new") {
                        openURL(url)
                    }
                } label: {
                    Text("Post to GitHub")
                }
            } label: {
                Text("Contact Us")
            }
        }
    
        CommandGroup(replacing: .newItem) {
            SwiftUIShortcutView(title: "New Project",
                                key: NEW_PROJECT_SHORTCUT) {
                store.createNewProjectSideEffect(isProjectImport: false)
            }

            SwiftUIShortcutView(title: "New Project from Sample",
                                key: NEW_PROJECT_SHORTCUT,
                                eventModifiers: [.command, .shift]) {
                store.conditionallToggleSampleProjectsModal()
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
                    dispatch(SelectAllShortcutKeyPressed())
                }
                
                SwiftUIShortcutView(title: "Group",
                                    key: CREATE_GROUP_SHORTCUT) {
                    let cannotCreateLayerGroup = !isSidebarFocused || !groupButtonEnabled
                    
                    if cannotCreateLayerGroup {
                        dispatch(GroupNodeCreated(isComponent: false))
                    } else {
                        self.graph?.layersSidebarViewModel.sidebarGroupCreated()
                    }
                }
                
                SwiftUIShortcutView(title: "Ungroup",
                                    key: DELETE_SELECTED_NODES_SHORTCUT,
                                    eventModifiers: [.command]) {
                    
                    let cannotUngroupLayer = !isSidebarFocused || !ungroupButtonEnabled
                    
                    if cannotUngroupLayer {
                        dispatch(SelectedGroupNodesUncreated())
                    } else {
                        self.graph?.layersSidebarViewModel.sidebarGroupUncreated()
                    }
                }
                
            } // replacing: .pasteboard
            
        } // if activeProject
    }
}
