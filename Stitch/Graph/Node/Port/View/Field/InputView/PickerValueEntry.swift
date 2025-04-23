//  PickerView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/14/21.
//

import SwiftUI
import StitchSchemaKit

struct MediaPickerChoicesView: View {
    let choices: [FieldValueMedia]

    var body: some View {
        ForEach(choices) { choice in
            StitchTextView(string: choice.name)
                .tag(choice)    // Appears to fix rendering issue
        }
    }
}

struct MediaPickerButtons: View {
    
    @Environment(\.appTheme) var theme
    
    let rowObserver: InputNodeRowObserver
    let node: NodeViewModel
    let mediaType: NodeMediaSupport
    let choices: [FieldValueMedia]
    let isFieldInsideLayerInspector: Bool
    let graph: GraphState
    let isSelectedInspectorRow: Bool
    let activeIndex: ActiveIndex

    var body: some View {
        ForEach(choices) { choice in
            StitchButton {
                // Update binding which later gets processed by view model
                choice.handleSelection(rowObserver: rowObserver,
                                       node: node,
                                       mediaType: mediaType,
                                       isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                       activeIndex: activeIndex,
                                       graph: graph)
            } label: {
                // We add a value for truncating text here to ensure that the title view in the picker does not stretch too long when importing a file with a long tiel
                //                StitchTextView(string: choice.getName(mediaDict: mediaManager.mediaDict), truncateAt: 30)
                StitchTextView(string: choice.name,
                               fontColor: isSelectedInspectorRow ? theme.fontColor : STITCH_TITLE_FONT_COLOR)
            }
        }
    }
}

/// Consolidates some logic for Menus. Catalyst requires a different style than iPad.
struct StitchMenu<ContentCatalyst: View, ContentIPad: View, Label: View>: View {
    let id: NodeId
    let selection: String
    @ViewBuilder var contentCatalyst: () -> ContentCatalyst
    @ViewBuilder var contentIPad: () -> ContentIPad
    @ViewBuilder var label: () -> Label

    var body: some View {
        menu
    }

    // DO NOT wrap in `Group`; breaks key presses on Catalyst
    var menu: some View {
        #if targetEnvironment(macCatalyst)

        Menu {
            contentCatalyst()
        } label: {
            label()
        }
        .buttonStyle(.plain) // fixes Catalyst accent-color issue
        #else
        Menu {
            contentIPad()
        } label: {
            label()
        }
        #endif
    }
}
