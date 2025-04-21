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
struct MediaInputFieldValueView: View {
    let viewModel: FieldViewModel
    let rowObserver: InputNodeRowObserver
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
    let mediaType: NodeMediaSupport
    
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
            MediaPickerValueEntry(rowObserver: rowObserver,
                                  isUpstreamValue: isUpstreamValue,
                                  mediaValue: media,
                                  label: mediaName,
                                  nodeKind: nodeKind,
                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                  graph: graph,
                                  isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues,
                                  isSelectedInspectorRow: isSelectedInspectorRow,
                                  activeIndex: document.activeIndex,
                                  mediaType: mediaType)
            
            MediaFieldLabelView(viewModel: viewModel,
                                inputType: viewModel.id.rowId.portType,
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

// Used by both input and output
struct MediaFieldLabelView: View {
    @State private var mediaObserver: MediaViewModel?
    
    let viewModel: FieldViewModel
    let inputType: NodeIOPortType // patch portId or layer keyPath; but
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
        self.mediaObserver = node.getMediaObserver(portType: inputType,
                                                   // TODO: loop support
                                                   loopIndex: 0,
                                                   // TODO: remove media ID check
                                                   mediaId: nil)
    }
    
    var isVisualMediaPort: Bool {
        self.coordinate.portType.isVisualMeiaPortType &&
        self.node.kind.isVisualMediaNode
    }
    
    var media: GraphMediaValue? {
        // Fixes issue where we grab visual media for wrong port
        guard isVisualMediaPort else { return nil }
        
        let _media = self.isInput ? self.mediaObserver?.inputMedia : self.mediaObserver?.computedMedia
        
        return _media
    }
    
    @ViewBuilder
    func createMediaView<Content>(emptyView: () -> Content) -> some View where Content: View {
        switch self.media?.mediaObject {
        case .image(let image):
            ValueStitchImageView(image: image)
        case .video(let video):
            ValueStitchVideoView(thumbnail: video.thumbnail)
        default:
            emptyView()
        }
    }
    
    @ViewBuilder
    var visualMediaView: some View {
        // For image and video media pickers,
        // show both dropdown and thumbnail
        self.createMediaView() {
            NilImageView()
        }
        .onChange(of: self.viewModel.fieldValue, initial: true) {
            if self.isVisualMediaPort {
                self.updateMediaObserver()
            }
        }
    }
    
    var body: some View {
        Group {
            if isMultiselectInspectorInputWithHeterogenousValues {
                NilImageView()
            } else if isVisualMediaPort {
                // For image and video media pickers,
                // show both dropdown and thumbnail
                visualMediaView
            } else {
                // Similar logic to visualMediaView but nil case displays empty
                self.createMediaView() {
                    Color.clear
                }
            }
        }
        .onChange(of: document.activeIndex, initial: true) {
            self.updateMediaObserver()
        }
    }
}
