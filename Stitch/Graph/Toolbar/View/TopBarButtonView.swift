//
//  TopBarButtonView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/12/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct iPadTopBarButtonWithMenu<MenuContent: View>: View {
    let iconName: String
    let tooltip: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Button(tooltip,
                   systemImage: iconName,
                   action: { })
            //            .buttonStyle(.borderless)
        }
    }
}


struct iPadTopBarButton: View {
    let iconName: String
    let tooltip: String
    let action: @MainActor () -> Void
    var label: String? // non-nil show label for menu items

    var body: some View {
        if let label = label {
            Button(action: action) {
                Label(label, systemImage: iconName)
            }
            //            .buttonStyle(.borderless)
        } else {
            Button(tooltip,
                   systemImage: iconName,
                   action: action)
            //            .buttonStyle(.borderless)
        }
    }
}

struct iPadTopBarButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(TOPBAR_SPACING)
            .hoverEffect(.highlight)
    }
}

struct iPadNavBarButton: View {
    let iconName: String
    let tooltip: String
    let action: () -> Void
    var rotationZ: CGFloat = 0 // some icons stay the same but just get rotated

    var body: some View {
        Button(tooltip,
               systemImage: iconName,
               action: action)
        //        .buttonStyle(.borderless)
        .rotation3DEffect(Angle(degrees: rotationZ),
                          axis: (x: 0, y: 0, z: rotationZ))
    }
}


#if !targetEnvironment(macCatalyst)
struct iPadGraphTopBarButtons: View {

    @Bindable var document: StitchDocumentViewModel
    let isDebugMode: Bool
    let hasActiveGroupFocused: Bool
    let isFullscreen: Bool // = false
    let isPreviewWindowShown: Bool // = true
    let restartPrototypeWindowIconRotationZ: CGFloat

    @ViewBuilder
    var miscButton: some View {
        iPadGraphTopBarMiscMenu(document: document)
    }
    
    var body: some View {
                        
//        ControlGroup {
//            Picker("", selection: $document.selectedTab) {
//                ForEach(ProjectTab.allCases) { projectTab in
//                    Image(systemName: projectTab.systemIcon)
//                        .tag(projectTab)
//                }
//            }
//            .pickerStyle(.segmented)
//        }
        
        
//        // go up a traversal level
//        iPadNavBarButton(iconName: .GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME,
//                         tooltip: "Go up one traversal level",
//                         action: { dispatch(GoUpOneTraversalLevel()) })
//        .disabled(hasActiveGroupFocused ? false : true)
//        
//        iPadTopBarButtonWithMenu(iconName: .sfSymbol(.AI_MAGIC_TEMP_MENU_SF_SYMBOL_NAME)) {
//            StitchButton {
//                dispatch(ShowAINodePromptEntryModal())
//            } label: {
//                Label(String.CREATE_CUSTOM_NODE_WITH_AI,
//                      systemImage: "rectangle")
//            }
//            StitchButton {
//                dispatch(ToggleInsertNodeMenu())
//            } label: {
//                Label("Add Nodes",
//                      systemImage: "rectangle.on.rectangle")
//            }
//        }
        
//        // OpenAI Configuration Picker - only show in debug builds
//#if DEV_DEBUG || STITCH_AI_TESTING
////        ToolbarItem {
//            //            ControlGroup {
//            OpenAIConfigurationPicker(document: document)
//            //            }
////        }
//        
//#endif
        
//        iPadNavBarButton(iconName: .ADD_NODE_SF_SYMBOL_NAME,
//                         tooltip: "Add Node",
//                         action: { dispatch(ToggleInsertNodeMenu()) })
//        
//        // toggle preview window
//        iPadNavBarButton(
//            iconName: isPreviewWindowShown ? .HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME : .SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME,
//            tooltip: "Toggle Prototype Window",
//            action: PREVIEW_SHOW_TOGGLE_ACTION)
        
//        // refresh prototype
//        iPadNavBarButton(iconName: .RESTART_PROTOTYPE_SF_SYMBOL_NAME,
//                         tooltip: "Restart Prototype",
//                         action: RESTART_PROTOTYPE_ACTION,
//                         rotationZ: restartPrototypeWindowIconRotationZ)
        
//        iPadTopBarButtonWithMenu(iconName: .AI_MAGIC_TEMP_MENU_SF_SYMBOL_NAME,
//                                 tooltip: "Create with AI") {
//            StitchButton {
//                dispatch(ShowAINodePromptEntryModal())
//            } label: {
//                Label(String.CREATE_CUSTOM_NODE_WITH_AI,
//                      systemImage: "rectangle")
//            }
//            StitchButton {
//                dispatch(ToggleInsertNodeMenu())
//            } label: {
//                Label("Add Nodes",
//                      systemImage: "rectangle.on.rectangle")
//            }
//        }
        
//        // full screen
//        iPadNavBarButton(
//            iconName: isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME,
//            tooltip: "Toggle Fullscreen",
//            action: PREVIEW_FULL_SCREEN_ACTION)
        
        // the misc (...) button
//        miscButton
        //                .popoverTip(document.stitchAITrainingTip, arrowEdge: .top)
                
    }
}
#endif

struct iPadGraphTopBarMiscMenu: View {
    @Bindable var document: StitchDocumentViewModel

    var body: some View {
        Menu {
            
            iPadTopBarButton(iconName: .FIND_NODE_ON_GRAPH,
                             tooltip: "Find Node",
                             action: { dispatch(FindSomeCanvasItemOnGraph())},
                             label: "Find Node")

            iPadTopBarButton(iconName: UNDO_ICON_NAME_STRING,
                             tooltip: "Undo",
                             action: UNDO_ACTION,
                             label: UNDO_ICON_LABEL)

            iPadTopBarButton(iconName: REDO_ICON_NAME_STRING,
                             tooltip: "Redo",
                             action: REDO_ACTION,
                             label: REDO_ICON_LABEL)

            iPadTopBarButton(iconName: FILE_IMPORT_ICON_NAME_STRING,
                             tooltip: "Import File",
                             action: FILE_IMPORT_ACTION,
                             label: FILE_IMPORT_LABEL)

            TopBarSharingButtonsView(document: document)
//                .modifier(iPadTopBarButtonStyle())

            TopBarFeedbackButtonsView(document: self.document)
//                .modifier(iPadTopBarButtonStyle())

            iPadTopBarButton(iconName: .SETTINGS_SF_SYMBOL_NAME,
                             tooltip: "Settings",
                             action: PROJECT_SETTINGS_ACTION,
                             label: PROJECT_SETTINGS_LABEL)
        } label: {
            Button(action: {} ) {
                Image(systemName: "ellipsis.circle")
            }
        } // menu
    }
}
