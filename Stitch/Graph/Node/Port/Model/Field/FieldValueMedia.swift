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
    func handleSelection(inputCoordinate: InputCoordinate,
                         mediaType: SupportedMediaFormat,
                         isFieldInsideLayerInspector: Bool,
                         graph: GraphState) {
        switch self {
        case .none:
            dispatch(MediaPickerNoneChanged(input: inputCoordinate,
                                            isFieldInsideLayerInspector: isFieldInsideLayerInspector))
        
        case .importButton:
            
            var destinationInputs = [inputCoordinate]
            
            if let layerInput = inputCoordinate.layerInput,
               let multiselectInput = graph.getLayerMultiselectInput(
                layerInput: layerInput.layerInput,
                isFieldInsideLayerInspector: isFieldInsideLayerInspector) {
            
                destinationInputs = multiselectInput.multiselectObservers(graph).map({ (observer: LayerInputObserver) in
                    InputCoordinate(portType: .keyPath(layerInput),
                                    nodeId: observer.rowObserver.id.nodeId)
                })
            }
            
            let payload = NodeMediaImportPayload(
                destinationInputs: destinationInputs, // inputCoordinate,
                mediaFormat: mediaType)

            dispatch(ShowFileImportModal(nodeImportPayload: payload))
        
        case .media(let mediaValue):
            dispatch(MediaPickerChanged(selectedValue: .asyncMedia(mediaValue),
                                        mediaType: mediaType,
                                        input: inputCoordinate,
                                        isFieldInsideLayerInspector: isFieldInsideLayerInspector))
            
        case .defaultMedia(let defaultMedia):
            let mediaValue = AsyncMediaValue(id: .init(),
                                             dataType: .source(defaultMedia.mediaKey),
                                             label: defaultMedia.mediaKey.filename)
            let portValue = PortValue.asyncMedia(mediaValue)
            
            dispatch(MediaPickerChanged(selectedValue: portValue,
                                        mediaType: mediaType,
                                        input: inputCoordinate,
                                        isFieldInsideLayerInspector: isFieldInsideLayerInspector))
        }
    }
}
