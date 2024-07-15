//
//  MLModelPickerValueEntry.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/22.
//

import SwiftUI
import StitchSchemaKit

struct MediaPickerValueEntry: View {
    let coordinate: InputCoordinate
    let isUpstreamValue: Bool   // is input port connected
    let mediaValue: FieldValueMedia
    let nodeKind: NodeKind

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
                               choices: [.importButton])

                    // Only show the incoming value as an option if there's an incoming edge
                    if isUpstreamValue {
                        MediaPickerButtons(inputCoordinate: coordinate,
                                           mediaType: mediaType,
                                           choices: [])

                    }

                    // If empty value is selected, don't show duplicate label for it
                    else if mediaValue != .none {
                        MediaPickerButtons(inputCoordinate: coordinate,
                                           mediaType: mediaType,
                                           choices: [mediaValue])
                    }

                    Divider()
                    MediaPickerButtons(inputCoordinate: coordinate,
                                       mediaType: mediaType,
                                       choices: defaultOptions)
                   },

                   contentIPad: {
                    Picker("", selection: createBinding(mediaValue, { $0.handleSelection(inputCoordinate: coordinate,
                                                                                         mediaType: mediaType) })) {
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

                    TruncatedTextView(label, truncateAt: 30)
                   })
    }
}
