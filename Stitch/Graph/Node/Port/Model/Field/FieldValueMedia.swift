//
//  FieldValueMedia.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

enum FieldValueMedia: Equatable, Hashable {
    case none
    case importButton
    case media(AsyncMediaValue)
    case defaultMedia(DefaultMediaOption)
}

extension FieldValueMedia: Identifiable {
    var id: Int {
        switch self {
        case .none:
            return MEDIA_EMPTY_ID.hashValue
        case .importButton:
            return IMPORT_BUTTON_ID.hashValue
        case .media(let media):
            return media.hashValue
        case .defaultMedia(let media):
            return media.hashValue
        }
    }
}

extension FieldValueMedia {
    var hasMediaSelected: Bool {
        switch self {
        case .media, .defaultMedia:
            return true
        default:
            return false
        }
    }
    
    var name: String {
        switch self {
        case .none:
            return MEDIA_EMPTY_NAME
        case .importButton:
            return IMPORT_BUTTON_DISPLAY
        case .media(let media):
            return media.label
        case .defaultMedia(let defaultMedia):
            return defaultMedia.name
        }
    }

    @MainActor
    func handleSelection(rowObserver: InputNodeRowObserver,
                         mediaType: NodeMediaSupport,
                         isFieldInsideLayerInspector: Bool,
                         activeIndex: ActiveIndex,
                         graph: GraphState) {
        switch self {
        case .none:
            graph.mediaPickerNoneChanged(rowObserver: rowObserver,
                                         activeIndex: activeIndex,
                                         isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        
        case .importButton:
            
            var destinationInputs = [rowObserver.id]
            
            if let layerInput = rowObserver.id.layerInput,
               let multiselectInput = graph.getLayerMultiselectInput(
                layerInput: layerInput.layerInput,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector) {
            
                destinationInputs = multiselectInput.multiselectObservers(graph).map({ (observer: LayerInputObserver) in
                    InputCoordinate(portType: .keyPath(layerInput),
                                    nodeId: observer.packedRowObserver.id.nodeId)
                })
            }
            
            let payload = NodeMediaImportPayload(
                destinationInputs: destinationInputs, // inputCoordinate,
                mediaFormat: mediaType)

            dispatch(ShowFileImportModal(nodeImportPayload: payload))
        
        case .media(let mediaValue):
            graph.mediaPickerChanged(selectedValue: .asyncMedia(mediaValue),
                                     mediaType: mediaType,
                                     rowObserver: rowObserver,
                                     activeIndex: activeIndex,
                                     isFieldInsideLayerInspector: isFieldInsideLayerInspector)
            
        case .defaultMedia(let defaultMedia):
            let mediaValue = AsyncMediaValue(id: .init(),
                                             dataType: .source(defaultMedia.mediaKey),
                                             label: defaultMedia.mediaKey.filename)
            let portValue = PortValue.asyncMedia(mediaValue)
            
            graph.mediaPickerChanged(selectedValue: portValue,
                                     mediaType: mediaType,
                                     rowObserver: rowObserver,
                                     activeIndex: activeIndex,
                                     isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        }
    }
}
