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
    
    let coordinate: InputCoordinate
    let isUpstreamValue: Bool   // is input port connected
    let mediaValue: FieldValueMedia
    let nodeKind: NodeKind
    let isFieldInsideLayerInspector: Bool
    let graph: GraphState // Doesn't need to be @Bindable, since not directly relied on in the UI for a render-cycle
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    let isSelectedInspectorRow: Bool
    
    var mediaType: SupportedMediaFormat {
        nodeKind.mediaType
    }
    
    var body: some View {
        let defaultOptions = DefaultMediaOption
            .getDefaultOptions(for: nodeKind,
                               isMediaCurrentlySelected: mediaValue.hasMediaSelected)
        
        let label = mediaValue.getName()
                
        StitchMenu(id: coordinate.nodeId,
                   selection: label,
                   contentCatalyst: {
            // Import button and any default media
            MediaPickerButtons(inputCoordinate: coordinate,
                               mediaType: mediaType,
                               choices: [.importButton],
                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                               graph: graph,
                               isSelectedInspectorRow: isSelectedInspectorRow)
            
            // Only show the incoming value as an option if there's an incoming edge
            if isUpstreamValue {
                MediaPickerButtons(inputCoordinate: coordinate,
                                   mediaType: mediaType,
                                   choices: [],
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   graph: graph,
                                   isSelectedInspectorRow: isSelectedInspectorRow)
                
            }
            
            // If empty value is selected, don't show duplicate label for it
            else if mediaValue != .none {
                MediaPickerButtons(inputCoordinate: coordinate,
                                   mediaType: mediaType,
                                   choices: [mediaValue],
                                   isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                   graph: graph,
                                   isSelectedInspectorRow: isSelectedInspectorRow)
            }
            
            Divider()
            MediaPickerButtons(inputCoordinate: coordinate,
                               mediaType: mediaType,
                               choices: defaultOptions,
                               isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                               graph: graph,
                               isSelectedInspectorRow: isSelectedInspectorRow)
        },
                   
                   contentIPad: {
            Picker("", selection: createBinding(mediaValue, { $0.handleSelection(inputCoordinate: coordinate,
                                                                                 mediaType: mediaType,
                                                                                 isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                                                                 graph: graph) })) {
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
        })
    }
}
