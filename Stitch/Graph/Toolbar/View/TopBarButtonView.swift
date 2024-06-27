//
//  TopBarButtonView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/12/23.
//

import SwiftUI
import StitchSchemaKit

// legacy; used for potentially-labeled buttons,
// including those that appear in the top bar's dropdown menu
struct iPadTopBarButton: View {
    let action: () -> Void
    let iconName: IconName
    var label: String? // non-nil show label

    var body: some View {
        StitchButton(action: action) {
            TopBarImageButton(iconName: iconName,
                              label: label)
        }
        .padding(TOPBAR_SPACING)
        .hoverEffect(.highlight)
    }
}

// Hack: use `Menu(primaryAction:)` to get native size and hover effect on iPad
struct iPadNavBarButton: View {
    let action: () -> Void
    let iconName: IconName
    var rotationZ: CGFloat = 0 // some icons stay the same but just get rotated

    var body: some View {
        Menu {
            // 'Empty menu' so that nothing happens when we tap the Menu's label
            EmptyView()
        } label: {
            Button(action: {}) {
                // TODO: any .resizable(), .fixedSize() etc. needed?
                iconName.image
                // TODO: why is this rotation changes sometimes animated, sometimes not?
                //                    .rotation3DEffect(Angle(degrees: rotationZ),
                //                                      axis: (x: 0, y: 0, z: rotationZ))
            }
        } primaryAction: {
            action()
        }
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

struct iPadGraphTopBarButtons: View {

    let graphUI: GraphUIState
    let hasActiveGroupFocused: Bool
    let isFullscreen: Bool // = false
    let isPreviewWindowShown: Bool // = true
    let restartPrototypeWindowIconRotationZ: CGFloat

    var llmRecordingModeEnabled: Bool
    var llmRecordingModeActive: Bool
    
    var body: some View {

        // TODO: why does `Group` but not `HStack` work here? Something to do with `Menu`?
        Group {
            
            iPadNavBarButton(action: { dispatch(LLMActionsJSONEntryModalOpened()) },
                             iconName: .sfSymbol(LLM_OPEN_JSON_ENTRY_MODAL_SF_SYMBOL))
            
            iPadNavBarButton(action: { dispatch(LLMRecordingToggled()) },
                             iconName: .sfSymbol(llmRecordingModeActive ? LLM_STOP_RECORDING_SF_SYMBOL : LLM_START_RECORDING_SF_SYMBOL))
            
            .opacity(llmRecordingModeEnabled ? 1 : 0)
            
            // go up a traversal level
                iPadNavBarButton(action: { dispatch(GoUpOneTraversalLevel()) },
                                 iconName: .sfSymbol(.GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME))
                .opacity(hasActiveGroupFocused ? 1 : 0)

            // add node
            iPadNavBarButton(action: INSERT_NODE_ACTION,
                             iconName: .sfSymbol(.ADD_NODE_SF_SYMBOL_NAME))
            
            iPadNavBarButton(action: { dispatch(FindSomeCanvasItemOnGraph()) },
                             iconName: .sfSymbol(.FIND_NODE_ON_GRAPH))

            // TODO: implement
            //            // new project
            //            iPadNavBarButton(action: NEW_PROJECT_ACTION,
            //                             iconName: .sfSymbol(.NEW_PROJECT_SF_SYMBOL_NAME))

            // toggle preview window
            iPadNavBarButton(
                action: PREVIEW_SHOW_TOGGLE_ACTION,
                iconName: .sfSymbol(.TOGGLE_PREVIEW_WINDOW_SF_SYMBOL_NAME),
                rotationZ: isPreviewWindowShown ? 0 : 180)

            // refresh prototype
            iPadNavBarButton(action: RESTART_PROTOTYPE_ACTION,
                             iconName: .sfSymbol(.RESTART_PROTOTYPE_SF_SYMBOL_NAME),
                             rotationZ: restartPrototypeWindowIconRotationZ)

            // full screen
            iPadNavBarButton(
                action: PREVIEW_FULL_SCREEN_ACTION,
                //                iconName: .sfSymbol(.EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME))
                iconName: .sfSymbol(isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME))

            // TODO: implement
            //            // share project
            //            iPadNavBarButton(action: { log("ProjectToolbarViewModifier: to be implemented") },
            //                             iconName: .sfSymbol(.SHARE_ICON_SF_SYMBOL_NAME))

            // the misc (...) button
            iPadGraphTopBarMiscMenu()
            
            if FeatureFlags.USE_LAYER_INSPECTOR {
                iPadNavBarButton(action: {
                    self.graphUI.showsLayerInspector.toggle()
                }, iconName: .sfSymbol("sidebar.right"))
            }
        }
    }
}

struct iPadGraphTopBarMiscMenu: View {

    var body: some View {
        Menu {
            iPadTopBarButton(action: UNDO_ACTION,
                             iconName: UNDO_ICON_NAME,
                             label: UNDO_ICON_LABEL)

            iPadTopBarButton(action: REDO_ACTION,
                             iconName: REDO_ICON_NAME,
                             label: REDO_ICON_LABEL)

            iPadTopBarButton(action: FILE_IMPORT_ACTION,
                             iconName: FILE_IMPORT_ICON_NAME,
                             label: FILE_IMPORT_LABEL)

            iPadTopBarButton(action: PROJECT_SETTINGS_ACTION,
                             iconName: PROJECT_SETTINGS_ICON_NAME,
                             label: PROJECT_SETTINGS_LABEL)
        } label: {
            Button(action: {}) {
                // TODO: any .resizable(), .fixedSize() etc. needed?
                TOP_BAR_MENU_ICON_NAME.image
            }
        } // menu
    }
}
