//
//  MediaPickerView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/30/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    /*
     Non-nil just when:
     - we have a layer input
     - in the layer inspector
     - and multiple layers are selected
     */
    @MainActor
    func getLayerMultiselectInput(layerInput: LayerInputPort?,
                                  isFieldInsideLayerInspector: Bool) -> LayerInputPort? {
        if isFieldInsideLayerInspector,
           let layerInput = layerInput {
            return self.getLayerMultiselectInput(for: layerInput)
        } else {
            return nil
        }
    }
}

/// Picker view for all imported media nodes (Core ML, image, audio, video etc.).
struct MediaFieldValueView: View {
    let inputCoordinate: InputCoordinate
    let inputLayerNodeRowData: LayerInputObserver?
    let isUpstreamValue: Bool
    let media: FieldValueMedia
    let nodeKind: NodeKind
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    
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
        if let inputLayerNodeRowData = inputLayerNodeRowData {
            @Bindable var inputLayerNodeRowData = inputLayerNodeRowData
            return inputLayerNodeRowData.fieldHasHeterogenousValues(
                fieldIndex,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
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
                                      graph: graph,
                                      isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues,
                                      isSelectedInspectorRow: isSelectedInspectorRow)
            }

            if let mediaObject = mediaObject {
                MediaFieldLabelView(mediaObject: mediaObject,
                                    inputCoordinate: inputCoordinate,
                                    isInput: isInput,
                                    fieldIndex: fieldIndex,
                                    isNodeSelected: isNodeSelected,
                                    isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues)
            } else {
                EmptyView()
            }
        }
    }
}

struct MediaFieldLabelView: View {
    let mediaObject: StitchMediaObject
    let inputCoordinate: InputCoordinate
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
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
