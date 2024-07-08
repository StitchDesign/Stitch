//
//  FieldGroupTypeViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias FieldGroupTypeViewModelList = [FieldGroupTypeViewModel]

final class FieldGroupTypeViewModel: ObservableObject {
    let type: FieldGroupType
    @Published var fieldObservers: FieldViewModels

    // Only used for ShapeCommand cases? e.g. `.curveTo` has "PointTo", "CurveFrom" etc. 'groups of fields'
    let groupLabel: String?

    // Since this could be one of many in a node's row
    let startingFieldIndex: Int

    init(type: FieldGroupType,
         coordinate: NodeIOCoordinate,
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

extension FieldGroupTypeViewModel: Identifiable {
    var id: FieldCoordinate {
        self.fieldObservers.first?.id ?? .init(input: .init(portId: -1, nodeId: UUID()),
                                               fieldIndex: -1)
    }
}

extension FieldGroupTypeViewModelList {
    @MainActor
    init(initialValue: PortValue,
         coordinate: NodeIOCoordinate,
         nodeIO: NodeIO,
         importedMediaObject: StitchMediaObject?) {
        switch initialValue.getNodeRowType(nodeIO: nodeIO) {
        case .size:
            self = [.init(type: .hW, coordinate: coordinate)]

        case .position:
            self = [.init(type: .xY, coordinate: coordinate)]

        case .point3D:
            self = [.init(type: .xYZ, coordinate: coordinate)]

        case .point4D:
            self = [.init(type: .xYZW, coordinate: coordinate)]

        case .shapeCommand(let shapeCommand):
            switch shapeCommand {
            case .closePath:
                self = [.init(type: .dropdown, coordinate: coordinate)]
            case .lineTo: // i.e. .moveTo or .lineTo
                self = [.init(type: .dropdown, coordinate: coordinate),
                        .init(type: .xY,
                              coordinate: coordinate,
                              groupLabel: "Point", // optional
                              // REQUIRED, else we get two dropdowns
                              startingFieldIndex: 1)
                ]
            case .curveTo:
                self = .init([
                    .init(type: .dropdown, coordinate: coordinate),
                    .init(type: .xY, coordinate: coordinate, groupLabel: "Point", startingFieldIndex: 1),
                    .init(type: .xY, coordinate: coordinate, groupLabel: "Curve From", startingFieldIndex: 3),
                    .init(type: .xY, coordinate: coordinate, groupLabel: "Curve To", startingFieldIndex: 5)
                ])
            case .output:
                self = [.init(type: .readOnly, coordinate: coordinate)]
            }

        case .singleDropdown:
            self = [.init(type: .dropdown, coordinate: coordinate)]

        case .textFontDropdown:
            // TODO: Can keep using .dropdown ?
            self = [.init(type: .dropdown,
                          coordinate: coordinate)
            ]

        case .bool:
            self = [.init(type: .bool, coordinate: coordinate)]

        case .asyncMedia:
            self = [.init(type: .asyncMedia, coordinate: coordinate)]

        case .number:
            self = [.init(type: .number, coordinate: coordinate)]

        case .string:
            self = [.init(type: .string, coordinate: coordinate)]

        case .layerDimension:
            self = [.init(type: .layerDimension, coordinate: coordinate)]

        case .pulse:
            self = [.init(type: .pulse, coordinate: coordinate)]

        case .color:
            self = [.init(type: .color, coordinate: coordinate)]

        case .json:
            self = [.init(type: .json, coordinate: coordinate)]

        case .assignedLayer:
            self = [.init(type: .assignedLayer, coordinate: coordinate)]

        case .anchoring:
            self = [.init(type: .anchoring, coordinate: coordinate)]

        case .readOnly:
            self = [.init(type: .readOnly, coordinate: coordinate)]
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

        guard fieldValuesList.count == self.count else {
            log("FieldGroupTypeViewModelList error: counts incorrect.")
            return
        }

        zip(self, fieldValuesList).forEach { fieldObserverGroup, fieldValues in
            fieldObserverGroup.updateFieldValues(fieldValues: fieldValues)
        }
    }
}
