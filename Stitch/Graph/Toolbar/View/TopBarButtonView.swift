//
//  TopBarButtonView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/12/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// legacy; used for potentially-labeled buttons,
// including those that appear in the top bar's dropdown menu
struct iPadTopBarButtonWithMenu<MenuContent: View>: View {
//    let action: @MainActor () -> Void
    let iconName: IconName
    // var label: String? // non-nil show label
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            // 'Empty menu' so that nothing happens when we tap the Menu's label
            menuContent()
        } label: {
            Button(action: { }) {
                iconName.image
            }
        }
    }
}


// legacy; used for potentially-labeled buttons,
// including those that appear in the top bar's dropdown menu
struct iPadTopBarButton: View {
    let action: @MainActor () -> Void
    let iconName: IconName
    var label: String? // non-nil show label

    var body: some View {
        StitchButton(action: action) {
            TopBarImageButton(iconName: iconName,
                              label: label)
        }
        .modifier(iPadTopBarButtonStyle())
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
        .rotation3DEffect(Angle(degrees: rotationZ),
                          axis: (x: 0, y: 0, z: rotationZ))
    }
}

// Generic helper button
struct TopBarImageButton: View {
    let iconName: IconName
    var label: String?

    var body: some View {
        if let label = label {
            Label {
                StitchTextView(string: label)
            } icon: {
                iconImage
            }
        } else {
            iconImage
        }
    }

    var iconImage: some View {
        // special case where we have to flip 90 degrees an existing SF Symbol
        let rotationZ: CGFloat = iconName == PREVIEW_HIDE_ICON_NAME ? 90 : 0

        return iconName.image
            .resizable()
            .scaledToFit()
            .foregroundColor(TOP_BAR_IMAGE_BUTTON_FOREGROUND_COLOR)
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
            .fixedSize()
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
    
//    @ViewBuilder
//    var miscButton: some View {
//        iPadGraphTopBarMiscMenu(document: document)
//    }
    
    var body: some View {
        
        
        
        ControlGroup {
            Picker("", selection: $document.selectedTab) {
                ForEach(ProjectTab.allCases) { projectTab in
                    Image(systemName: projectTab.systemIcon)
                        .tag(projectTab)
                }
            }
            .pickerStyle(.segmented)
        }
        
        
        
        // go up a traversal level
        iPadNavBarButton(iconName: .GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME,
                         tooltip: "Go up one traversal level",
                         action: { dispatch(GoUpOneTraversalLevel()) })
        .disabled(hasActiveGroupFocused ? false : true)
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
        
        iPadNavBarButton(iconName: .ADD_NODE_SF_SYMBOL_NAME,
                         tooltip: "Add Node",
                         action: { dispatch(ToggleInsertNodeMenu()) })
        
        // toggle preview window
        iPadNavBarButton(
            iconName: isPreviewWindowShown ? .HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME : .SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME,
            tooltip: "Toggle Prototype Window",
            action: PREVIEW_SHOW_TOGGLE_ACTION)
        
        // refresh prototype
        iPadNavBarButton(iconName: .RESTART_PROTOTYPE_SF_SYMBOL_NAME,
                         tooltip: "Restart Prototype",
                         action: RESTART_PROTOTYPE_ACTION,
                         rotationZ: restartPrototypeWindowIconRotationZ)
        
        iPadTopBarButtonWithMenu(iconName: .sfSymbol(.AI_MAGIC_TEMP_MENU_SF_SYMBOL_NAME)) {
            StitchButton {
                dispatch(ShowAINodePromptEntryModal())
            } label: {
                Label(String.CREATE_CUSTOM_NODE_WITH_AI,
                      systemImage: "rectangle")
            }
            StitchButton {
                dispatch(ToggleInsertNodeMenu())
            } label: {
                Label("Add Nodes",
                      systemImage: "rectangle.on.rectangle")
            }
        }
        
        // full screen
        iPadNavBarButton(
            iconName: isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME,
            tooltip: "Toggle Fullscreen",
            action: PREVIEW_FULL_SCREEN_ACTION)
        
        // the misc (...) button
//        miscButton
//        iPadGraphTopBarMiscMenu()
        //                .popoverTip(document.stitchAITrainingTip, arrowEdge: .top)
        
        
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
        
        
    }
}
#endif

struct iPadGraphTopBarMiscMenu: View {
    
    var body: some View {
        Menu {
            
//            iPadNavBarButton(
//                iconName: .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME,
//                tooltip: "Love me",
//                action: { })
            
            Button("love",
                   systemImage: .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME,
                   action: { })
            
//            iPadTopBarButton(action: { dispatch(FindSomeCanvasItemOnGraph())},
//                             iconName: .sfSymbol(.FIND_NODE_ON_GRAPH),
//                             label: "Find Node")
//            
//            iPadTopBarButton(action: UNDO_ACTION,
//                             iconName: UNDO_ICON_NAME,
//                             label: UNDO_ICON_LABEL)
//
//            iPadTopBarButton(action: REDO_ACTION,
//                             iconName: REDO_ICON_NAME,
//                             label: REDO_ICON_LABEL)
//
//            iPadTopBarButton(action: FILE_IMPORT_ACTION,
//                             iconName: FILE_IMPORT_ICON_NAME,
//                             label: FILE_IMPORT_LABEL)
//            
////            TopBarSharingButtonsView(document: document)
////                .modifier(iPadTopBarButtonStyle())
//
//            TopBarFeedbackButtonsView(document: self.document)
//                .modifier(iPadTopBarButtonStyle())
//            
//            iPadTopBarButton(action: PROJECT_SETTINGS_ACTION,
//                             iconName: PROJECT_SETTINGS_ICON_NAME,
//                             label: PROJECT_SETTINGS_LABEL)
        } label: {
            Button(action: {} ) {
                Image(systemName: "ellipsis.circle")
            }
            
//            Button("More",
//                   systemImage: "ellipsis.circle",
//                   action: { })
            
//            Button(action: {}) {
//                // TODO: any .resizable(), .fixedSize() etc. needed?
//                TOP_BAR_MENU_ICON_NAME.image
//            }
        } // menu
    }
}
