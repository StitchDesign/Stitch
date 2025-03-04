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
struct MediaFieldValueView<Field: FieldViewModel>: View {
    let viewModel: Field
    let rowViewModel: Field.NodeRowType
    let rowObserver: Field.NodeRowType.RowObserver
    let node: NodeViewModel
    let isUpstreamValue: Bool
    let media: FieldValueMedia
    let mediaName: String
    let nodeKind: NodeKind
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    
    @Bindable var graph: GraphState
    let document: StitchDocumentViewModel

    var alignment: Alignment { isInput ? .leading : .trailing }
    
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

    var body: some View {
        // MARK: using StitchMediaObject is more dangerous than GraphMediaValue as it won't refresh when media is changed, causing media to be retained
        
        HStack {
            if isInput && canUseMediaPicker,
               let inputRowObserver = rowObserver as? InputNodeRowObserver {
                MediaPickerValueEntry(rowObserver: inputRowObserver,
                                      isUpstreamValue: isUpstreamValue,
                                      mediaValue: media,
                                      label: mediaName,
                                      nodeKind: nodeKind,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                      graph: graph,
                                      isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues,
                                      isSelectedInspectorRow: isSelectedInspectorRow,
                                      activeIndex: document.activeIndex)
                .onChange(of: mediaName, initial: true) {
                    print("media name in inner value view: \(mediaName)")
                }
            }
            
            MediaFieldLabelView(viewModel: viewModel,
                                rowViewModel: rowViewModel,
                                node: node,
                                graph: graph,
                                document: document,
                                coordinate: rowObserver.id,
                                isInput: isInput,
                                fieldIndex: fieldIndex,
                                isNodeSelected: isNodeSelected,
                                isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues)
        }
    }
}

struct MediaFieldLabelView<Field: FieldViewModel>: View {
    @State private var mediaObserver: MediaViewModel?
    
    let viewModel: Field
    let rowViewModel: Field.NodeRowType
    let node: NodeViewModel
    let graph: GraphState
    let document: StitchDocumentViewModel
    let coordinate: InputCoordinate
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    
    @MainActor
    func updateMediaObserver() {
        self.mediaObserver = Field.getMediaObserver(node: node,
                                                    rowViewModel: rowViewModel,
                                                    graph: graph,
                                                    activeIndex: document.activeIndex)
    }
    
    var isVisualMediaPort: Bool {
        self.coordinate.portId == 0 && (
            self.node.kind.isVisualMediaLayerNode ||
            
            // Checks if patch node uses observer object used for storing visual media
            (self.node.ephemeralObservers?.first as? MediaEvalOpViewable) != nil
        )
    }
    
    @ViewBuilder
    func visualMediaView(mediaObserver: MediaViewModel?) -> some View {
        // For image and video media pickers,
        // show both dropdown and thumbnail
        switch mediaObserver?.currentMedia?.mediaObject {
        case .image(let image):
            ValueStitchImageView(image: image)
        case .video(let video):
            ValueStitchVideoView(thumbnail: video.thumbnail)

        default:
            if !isVisualMediaPort {
                NilImageView()
            } else {
                // Other media types: don't show label.
                Color.clear
                    .onChange(of: self.viewModel.fieldValue, initial: true) {
                        if self.isVisualMediaPort {
                            self.updateMediaObserver()
                        }
                    }
            }
        }
    }
    
    var body: some View {
        Group {
            if isMultiselectInspectorInputWithHeterogenousValues {
                NilImageView()
            } else {
                visualMediaView(mediaObserver: self.mediaObserver)
            }
        }
        .onChange(of: document.activeIndex, initial: true) {
            self.updateMediaObserver()
        }
    }
}
