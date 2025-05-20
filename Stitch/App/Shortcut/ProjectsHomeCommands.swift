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
    
    var textFieldFocused: Bool {
        guard !focusedField.isDefined else {
            return true
        }
        
        switch activeReduxFocusedField {
        case .sidebar, .prototypeWindow, .none:
            // no text field in these cases
            return false
            
        default:
            return true
        }
    }
    
    var disabledGraphDelete: Bool {
        guard let document = store.currentDocument else {
            return true
        }
        
        if document.isSidebarFocused {
            return document.visibleGraph.layersSidebarViewModel.selectionState.items.isEmpty
        } else {
            return document.visibleGraph.selectedCanvasItems.isEmpty
        }
    }
    
    var body: some Commands {
        // MARK: no support for conditionally display commands--they'll never appear with an if statement
        GraphCommands(store: store,
                      textFieldFocused: textFieldFocused)
        
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
                                    key: "O",
                                    eventModifiers: [.command],
                                    disabled: !activeProject) {
                    FILE_IMPORT_ACTION()
                }
            }
            
            // MARK: splitting into multiple shortcuts breaks commands when using same CMD + R
            SwiftUIShortcutView(title: activeProject ? "Restart Prototype" : "Refresh Projects",
                                key: .init("R")) {
                if activeProject {
                    dispatch(PrototypeRestartedAction())
                } else {
                    store.allProjectUrls = []
                    dispatch(DirectoryUpdated())
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
        
        CommandGroup(replacing: .pasteboard) {
            // Not shown in menu when no active project;
            // Disabled when we have focused text input
            SwiftUIShortcutView(title: "Cut",
                                key: CUT_SELECTED_NODES_SHORTCUT,
                                disabled: textFieldFocused || !activeProject) {
                log("cut shortcut")
                // cuts both nodes and comments
                dispatch(SelectedGraphItemsCut())
            }
            
            SwiftUIShortcutView(title: "Copy",
                                key: COPY_SELECTED_NODES_SHORTCUT,
                                disabled: textFieldFocused || !activeProject) {
                log("copy shortcut")
                // copies both nodes and comments
                dispatch(SelectedGraphItemsCopied())
            }
            
            SwiftUIShortcutView(title: "Paste",
                                key: PASTE_SELECTED_NODES_SHORTCUT,
                                disabled: textFieldFocused || !activeProject) {
                log("paste shortcut")
                // pastes both nodes and comments
                dispatch(SelectedGraphItemsPasted())
            }
            
            SwiftUIShortcutView(title: "Duplicate",
                                key: DUPLICATE_SELECTED_NODES_SHORTCUT,
                                disabled: textFieldFocused || !activeProject) {
                dispatch(DuplicateShortcutKeyPressed())
            }
            
            // TODO: should CMD+Delete ungroup a GroupNode on the canvas, as it ungroups a LayerGroup in the sidebar?
            SwiftUIShortcutView(title: "Delete",
                                key: DELETE_SELECTED_NODES_SHORTCUT,
                                // empty list = do not require CMD
                                eventModifiers: DELETE_SELECTED_NODES_SHORTCUT_MODIFIERS,
                                disabled: disabledGraphDelete) {
                // deletes both selected nodes and selected comments
                dispatch(DeleteShortcutKeyPressed())
            }
        }
    }
}
