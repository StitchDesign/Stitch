//
//  FieldGroupTypeViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias FieldGroupTypeViewModelList<FieldType: FieldViewModel> = [FieldGroupTypeViewModel<FieldType>]

@Observable
final class FieldGroupTypeViewModel<FieldType: FieldViewModel> {
    let type: FieldGroupType
    var fieldObservers: [FieldType]

    let groupLabel: String?

    // Since this could be one of many in a node's row
    let startingFieldIndex: Int

    init(type: FieldGroupType,
         coordinate: FieldType.PortId,
         groupLabel: String? = nil,
         startingFieldIndex: Int = 0) {
        self.type = type
        self.groupLabel = groupLabel
        self.startingFieldIndex = startingFieldIndex
        self.fieldObservers = .init(type,
                                    coordinate: coordinate,
                                    startingFieldIndex: startingFieldIndex)
    }

    /// Updates observer objects with latest data.
    @MainActor
    func updateFieldValues(fieldValues: FieldValues) {
        guard fieldValues.count == fieldObservers.count else {
            log("FieldGroupTypeViewModel error: non-equal count of field values to observer objects for \(type).")
            return
        }

        fieldObservers.enumerated().forEach { index, observer in
            let oldValue = observer.fieldValue
            let newValue = fieldValues[index]

            if oldValue != newValue {
                observer.fieldValue = newValue
            }
        }
    }
}

extension FieldGroupTypeViewModel<InputFieldViewModel>: Identifiable {
    var id: FieldCoordinate {
        self.fieldObservers.first?.id ?? .init(input: .init(portId: -1, 
                                                            canvasId: .node(.init())),
                                               fieldIndex: -1)
    }
}

//extension Array where Element: FieldGroupTypeViewModel<InputFieldViewModel> {
extension NodeRowViewModel {
    @MainActor
    func createFieldValueTypes(initialValue: PortValue,
                               coordinate: Self.FieldType.PortId,
                               nodeIO: NodeIO,
                               importedMediaObject: StitchMediaObject?) -> FieldGroupTypeViewModelList<Self.FieldType> {
        switch initialValue.getNodeRowType(nodeIO: nodeIO) {
        case .size:
            self.fieldValueTypes = [.init(type: .hW, coordinate: coordinate)]

        case .position:
            self.fieldValueTypes = [.init(type: .xY, coordinate: coordinate)]

        case .point3D:
            self.fieldValueTypes = [.init(type: .xYZ, coordinate: coordinate)]

        case .point4D:
            self.fieldValueTypes = [.init(type: .xYZW, coordinate: coordinate)]

        case .shapeCommand(let shapeCommand):
            switch shapeCommand {
            case .closePath:
                self.fieldValueTypes = [.init(type: .dropdown, coordinate: coordinate)]
            case .lineTo: // i.e. .moveTo or .lineTo
                self.fieldValueTypes = [.init(type: .dropdown, coordinate: coordinate),
                        .init(type: .xY,
                              coordinate: coordinate,
                              groupLabel: "Point", // optional
                              // REQUIRED, else we get two dropdowns
                              startingFieldIndex: 1)
                ]
            case .curveTo:
                self.fieldValueTypes = .init([
                    .init(type: .dropdown, coordinate: coordinate),
                    .init(type: .xY, coordinate: coordinate, groupLabel: "Point", startingFieldIndex: 1),
                    .init(type: .xY, coordinate: coordinate, groupLabel: "Curve From", startingFieldIndex: 3),
                    .init(type: .xY, coordinate: coordinate, groupLabel: "Curve To", startingFieldIndex: 5)
                ])
            case .output:
                self.fieldValueTypes = [.init(type: .readOnly, coordinate: coordinate)]
            }

        case .singleDropdown:
            self.fieldValueTypes = [.init(type: .dropdown, coordinate: coordinate)]

        case .textFontDropdown:
            // TODO: Can keep using .dropdown ?
            self.fieldValueTypes = [.init(type: .dropdown,
                          coordinate: coordinate)
            ]

        case .bool:
            self.fieldValueTypes = [.init(type: .bool, coordinate: coordinate)]

        case .asyncMedia:
            self.fieldValueTypes = [.init(type: .asyncMedia, coordinate: coordinate)]

        case .number:
            self.fieldValueTypes = [.init(type: .number, coordinate: coordinate)]

        case .string:
            self.fieldValueTypes = [.init(type: .string, coordinate: coordinate)]

        case .layerDimension:
            self.fieldValueTypes = [.init(type: .layerDimension, coordinate: coordinate)]

        case .pulse:
            self.fieldValueTypes = [.init(type: .pulse, coordinate: coordinate)]

        case .color:
            self.fieldValueTypes = [.init(type: .color, coordinate: coordinate)]

        case .json:
            self.fieldValueTypes = [.init(type: .json, coordinate: coordinate)]

        case .assignedLayer:
            self.fieldValueTypes = [.init(type: .assignedLayer, coordinate: coordinate)]

        case .anchoring:
            self.fieldValueTypes = [.init(type: .anchoring, coordinate: coordinate)]

        case .readOnly:
            self.fieldValueTypes = [.init(type: .readOnly, coordinate: coordinate)]
        }

        self.updateAllFields(with: initialValue,
                             nodeIO: nodeIO,
                             importedMediaObject: importedMediaObject)
    }

    /// Updates new field values to existing view models.
    @MainActor
    func updateAllFields(with portValue: PortValue,
                         nodeIO: NodeIO,
                         importedMediaObject: StitchMediaObject?) {
        let fieldValuesList = portValue.createFieldValues(nodeIO: nodeIO,
                                                          importedMediaObject: importedMediaObject)
        let fieldsCount = self.fieldValueTypes.count

        guard fieldValuesList.count == fieldsCount else {
            log("FieldGroupTypeViewModelList error: counts incorrect.")
            return
        }

        zip(self.fieldValueTypes, fieldValuesList).forEach { fieldObserverGroup, fieldValues in
            fieldObserverGroup.updateFieldValues(fieldValues: fieldValues)
        }
    }
}
