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
    
    var hasSelectedInput: Bool {
        self.store.currentDocument?.selectedInput.isDefined ?? false
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

            if let document = store.currentDocument {
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
                
                
                // MARK: copy paste, cut paste
                
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
                
                // MARK: insert node shortcuts
                InsertNodeCommands(store: store,
                                   document: document)
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

        
        // MARK: undo + redo
        
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
