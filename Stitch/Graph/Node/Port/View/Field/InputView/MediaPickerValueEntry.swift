//
//  MLModelPickerValueEntry.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/22.
//

import SwiftUI
import StitchSchemaKit

struct MediaPickerValueEntry: View {
    
    @Environment(\.appTheme) var theme
    
    let rowObserver: InputNodeRowObserver
    let isUpstreamValue: Bool   // is input port connected
    let mediaValue: FieldValueMedia
    let label: String
    let nodeKind: NodeKind
    let isFieldInsideLayerInspector: Bool
    let graph: GraphState // Doesn't need to be @Bindable, since not directly relied on in the UI for a render-cycle
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    let isSelectedInspectorRow: Bool
    let activeIndex: ActiveIndex
    let mediaType: NodeMediaSupport
    
    var body: some View {
        let defaultOptions = DefaultMediaOption
            .getDefaultOptions(for: nodeKind,
                               coordinate: rowObserver.id,
                               isMediaCurrentlySelected: mediaValue.hasMediaSelected)
                
        StitchMenu(id: rowObserver.id.nodeId,
                   selection: label,
                   contentCatalyst: {
            // Import button and any default media
            MediaPickerButtons(rowObserver: rowObserver,
                               mediaType: mediaType,
                               choices: [.importButton],
                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                               graph: graph,
                               isSelectedInspectorRow: isSelectedInspectorRow,
                               activeIndex: activeIndex)
            
            // Only show the incoming value as an option if there's an incoming edge
            if isUpstreamValue {
                MediaPickerButtons(rowObserver: rowObserver,
                                   mediaType: mediaType,
                                   choices: [],
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   graph: graph,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   activeIndex: activeIndex)
                
            }
            
            // If empty value is selected, don't show duplicate label for it
            else if mediaValue != .none {
                MediaPickerButtons(rowObserver: rowObserver,
                                   mediaType: mediaType,
                                   choices: [mediaValue],
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   graph: graph,
                                   isSelectedInspectorRow: isSelectedInspectorRow,
                                   activeIndex: activeIndex)
            }
            
            Divider()
            MediaPickerButtons(rowObserver: rowObserver,
                               mediaType: mediaType,
                               choices: defaultOptions,
                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                               graph: graph,
                               isSelectedInspectorRow: isSelectedInspectorRow,
                               activeIndex: activeIndex)
        },
                   
                   contentIPad: {
            Picker("", selection: createBinding(mediaValue, {
                $0.handleSelection(rowObserver: rowObserver,
                                   mediaType: mediaType,
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   activeIndex: activeIndex,
                                   graph: graph)
            })) {
                // Import button and any default media
                MediaPickerChoicesView(choices: [.importButton])
                
                // Only show the incoming value as an option if there's an incoming edge
                if isUpstreamValue {
                    MediaPickerChoicesView(choices: [mediaValue])
                }
                
                Divider()
                MediaPickerChoicesView(choices: defaultOptions)
            }
            //                    .id(viewModel.pickerId)
        }, label: {
            // We add a value for truncating text here to ensure that the selection items view in the picker does not stretch too long when importing a file with a long title
            
            TruncatedTextView(isMultiselectInspectorInputWithHeterogenousValues ? .HETEROGENOUS_VALUES : label,
                              truncateAt: 30,
                              color: isSelectedInspectorRow ? theme.fontColor : STITCH_TITLE_FONT_COLOR)
            
            // Note: truncation logic does not quite seem correct; we were truncating at ~5-10 characters, not 30
            // TODO: better to just set a single width for all media-labels, regardless of length or "None" etc.?
            .modifier(MediaPickerValueEntryWidth(
                label: label,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector))
        })
    }
}

struct MediaPickerValueEntryWidth: ViewModifier {
    let label: String
    let isFieldInsideLayerInspector: Bool
    
    func body(content: Content) -> some View {
        if isFieldInsideLayerInspector {
            content
        } else {
            content
            .frame(minWidth: NODE_INPUT_OR_OUTPUT_WIDTH * 1.5,
                   maxWidth: NODE_INPUT_OR_OUTPUT_WIDTH * 2,
                   alignment: .leading)
        }
    }
    
    // Causes width change when switching between None vs import etc.
//    var minimumLabelWidth: CGFloat? {
//        label == "None" ? NODE_INPUT_OR_OUTPUT_WIDTH : (NODE_INPUT_OR_OUTPUT_WIDTH * 1.5)
//    }
}
