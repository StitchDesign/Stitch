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
    let coordinate: NodeIOCoordinate
    let layerInputObserver: LayerInputObserver?
    let isUpstreamValue: Bool
    let media: FieldValueMedia
    let mediaName: String
    let nodeKind: NodeKind
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    
    @Bindable var graph: GraphState

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

    @MainActor
    var isMultiselectInspectorInputWithHeterogenousValues: Bool {
        if let layerInputObserver = layerInputObserver {
            @Bindable var layerInputObserver = layerInputObserver
            return layerInputObserver.fieldHasHeterogenousValues(
                fieldIndex,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        } else {
            return false
        }
    }
    
    var body: some View {
        // MARK: using StitchMediaObject is more dangerous than GraphMediaValue as it won't refresh when media is changed, causing media to be retained
        
        HStack {
            if isInput && canUseMediaPicker {
                MediaPickerValueEntry(coordinate: coordinate,
                                      isUpstreamValue: isUpstreamValue,
                                      mediaValue: media,
                                      label: mediaName,
                                      nodeKind: nodeKind,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                      graph: graph,
                                      isMultiselectInspectorInputWithHeterogenousValues: isMultiselectInspectorInputWithHeterogenousValues,
                                      isSelectedInspectorRow: isSelectedInspectorRow)
                .onChange(of: mediaName, initial: true) {
                    print("media name in inner value view: \(mediaName)")
                }
            }
            
            MediaFieldLabelView(viewModel: viewModel,
                                graph: graph,
                                coordinate: coordinate,
                                nodeKind: nodeKind,
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
    let graph: GraphState
    let coordinate: InputCoordinate
    let nodeKind: NodeKind
    let isInput: Bool
    let fieldIndex: Int
    let isNodeSelected: Bool
    let isMultiselectInspectorInputWithHeterogenousValues: Bool
    
    var media: GraphMediaValue? {
        self.mediaObserver?.currentMedia
    }
    
    @MainActor
    func updateMediaObserver() {
        self.mediaObserver = viewModel.getMediaObserver()
    }
    
    // MARK: commented logic below causes render cycles, cheating with 0 for now
//    var loopCount: Int {
//        self.viewModel.rowViewModelDelegate?.rowDelegate?.allLoopedValues.count ?? .zero
//    }
    
    // An image/video input or output shows a placeholder 'blank image' if it currently contains no image/video.
    // TODO: update FieldValueMedia (or even PortValue ?) to distinguish between visual media and other types?
    var usesVisualMediaPlaceholder: Bool {
        
        switch nodeKind {
            
        case .patch(let patch):
            switch patch {
            case .soundImport:
                return false
            default:
                return true
            }
            
        case .layer(let layer):
            switch layer {
            case .model3D, .realityView:
                return false
            default:
                return true
            }
        
        // Should a group node input/output use the placeholder image? Maybe not?
        default:
            return false
        }
    }
    
    @ViewBuilder
    func visualMediaView(mediaObserver: MediaViewModel) -> some View {
        // For image and video media pickers,
        // show both dropdown and thumbnail
        switch mediaObserver.currentMedia?.mediaObject {
        case .image(let image):
            ValueStitchImageView(image: image)
        case .video(let video):
            ValueStitchVideoView(thumbnail: video.thumbnail)

        default:
            if usesVisualMediaPlaceholder {
                NilImageView()
            } else {
                // Other media types: don't show label.
                EmptyView()
            }
        }
    }
    
    var body: some View {
        Group {
            if isMultiselectInspectorInputWithHeterogenousValues {
                NilImageView()
            } else if let mediaObserver = self.mediaObserver {
                visualMediaView(mediaObserver: mediaObserver)
            } else {
                EmptyView()
            }
        }
        .onChange(of: graph.activeIndex, initial: true) {
            self.updateMediaObserver()
        }
//        .onChange(of: self.loopCount) {
//            self.updateMediaObserver()
//        }
    }
}
