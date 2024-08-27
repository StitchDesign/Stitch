//
//  MediaPickerView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/30/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/// Picker view for all imported media nodes (Core ML, image, audio, video etc.).
struct MediaFieldValueView: View {
    let inputCoordinate: InputCoordinate
    let isUpstreamValue: Bool
    let media: FieldValueMedia
    let nodeKind: NodeKind
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let hasIncomingEdge: Bool
    let isFieldInsideLayerInspector: Bool
    @Bindable var graph: GraphState

    var alignment: Alignment { isInput ? .leading : .trailing }
    
    var mediaObject: StitchMediaObject? {
        self.media.mediaObject
    }
    
    var canUseMediaPicker: Bool {
        switch nodeKind {
        case .patch(let patch):
            return patch.isMediaImportInput
        case .layer(let layer):
            return layer.usesCustomValueSpaceWidth
        default:
            return false
        }
    }

    @MainActor
    var isMultiselectInspectorInputWithHeterogenousValues: Bool {
        if isFieldInsideLayerInspector,
           let layerInput = inputCoordinate.layerInput {
        return graph.graphUI
                .propertySidebar
                .layerMultiselectObserver?
                .inputs.get(layerInput.layerInput)?
                .fieldsInMultiselectInputWithHeterogenousValues(graph).contains(fieldIndex) ?? false
        } else {
            return false
        }
    }
    
    var body: some View {
        HStack {
            if isInput && canUseMediaPicker {
                MediaPickerValueEntry(coordinate: inputCoordinate,
                                      isUpstreamValue: isUpstreamValue,
                                      mediaValue: media,
                                      nodeKind: nodeKind,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                      graph: graph)
            }

            if let mediaObject = mediaObject {
                MediaFieldLabelView(mediaObject: mediaObject,
                                    inputCoordinate: inputCoordinate,
                                    isInput: isInput,
                                    fieldIndex: fieldIndex,
                                    isNodeSelected: isNodeSelected,
                                    hasIncomingEdge: hasIncomingEdge,
                                    isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues)
            } else {
                EmptyView()
            }
        }
    }
}

// TODO: udpate with `fieldHasHeterogenousValues` logic
struct MediaFieldLabelView: View {
    let mediaObject: StitchMediaObject
    let inputCoordinate: InputCoordinate
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let hasIncomingEdge: Bool
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    
    var body: some View {
        
        if isMultiselectInspectorInputWithHeterogenousValues {
            NilImageView()
        } else {
            // For image and video media pickers,
            // show both dropdown and thumbnail
            switch mediaObject {
            case .image(let image):
                ValueStitchImageView(image: image)
            case .video(let video):
                ValueStitchVideoView(thumbnail: video.thumbnail)

            // Other media types: don't show label.
            default:
                EmptyView()
            }
        }
      
    }
}
