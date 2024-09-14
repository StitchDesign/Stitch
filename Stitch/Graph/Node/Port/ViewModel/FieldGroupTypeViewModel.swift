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
final class FieldGroupTypeViewModel<FieldType: FieldViewModel>: Identifiable {
    let type: FieldGroupType
    var fieldObservers: [FieldType]

    // Only used for ShapeCommand cases? e.g. `.curveTo` has "PointTo", "CurveFrom" etc. 'groups of fields'
    let groupLabel: String?

    // Since this could be one of many in a node's row
    let startingFieldIndex: Int
    
    init(type: FieldGroupType,
         groupLabel: String? = nil,
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         startingFieldIndex: Int = 0,
         rowViewModel: FieldType.NodeRowType? = nil) {
        self.type = type
        self.groupLabel = groupLabel
        self.startingFieldIndex = startingFieldIndex
        self.fieldObservers = .init(
            type,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex,
            startingFieldIndex: startingFieldIndex,
            rowViewModel: rowViewModel)
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

    var id: FieldCoordinate {
        self.fieldObservers.first?.id ?? .fakeFieldCoordinate
    }
}

extension NodeRowType {
    // TODO: must be some better way to get this information and/or tie it to `getFieldValueTypes`
    var getFieldGroupTypeForLayerInput: FieldGroupType {
        switch self {
        case .size:
            return .hW
        case .position:
            return .xY
        case .point3D:
            return .xYZ
        case .point4D:
            return .xYZW
        case .padding:
            return .padding
        case .shapeCommand(let shapeCommand):
            // No layer input uses shape command
            fatalErrorIfDebug()
            return .dropdown
        case .singleDropdown, .textFontDropdown:
            return .dropdown
        case .bool:
            return .bool
        case .asyncMedia:
            return .asyncMedia
        case .number:
            return .number
        case .string:
            return .string
        case .layerDimension:
            return .layerDimension
        case .pulse:
            return .pulse
        case .color:
            return .color
        case .json:
            return .json
        case .assignedLayer:
            return .assignedLayer
        case .pinTo:
            return .pinTo
        case .anchoring:
            return .anchoring
        case .readOnly:
            return .readOnly
        case .spacing:
            return .spacing
        }
    }
}

func getFieldValueTypes<FieldType: FieldViewModel>(initialValue: PortValue,
                                                   nodeIO: NodeIO,
                                                   unpackedPortParentFieldGroupType: FieldGroupType?,
                                                   unpackedPortIndex: Int?,
                                                   importedMediaObject: StitchMediaObject?) -> [FieldGroupTypeViewModel<FieldType>] {
    
    switch initialValue.getNodeRowType(nodeIO: nodeIO) {
        
    case .size:
        return [.init(type: .hW,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex)]
        
    case .position:
        return [.init(type: .xY,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .point3D:
        return [.init(type: .xYZ,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .point4D:
        return [.init(type: .xYZW,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .padding:
        return [.init(type: .padding,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .shapeCommand(let shapeCommand):
        switch shapeCommand {
        case .closePath:
            return [.init(type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex)]
        case .lineTo: // i.e. .moveTo or .lineTo
            return [.init(type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex),
                    .init(type: .xY,
                          groupLabel: "Point", // optional
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          // REQUIRED, else we get two dropdowns
                          startingFieldIndex: 1)
            ]
        case .curveTo:
            return .init([
                .init(type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex),
                .init(type: .xY,
                      groupLabel: "Point",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 1),
                .init(type: .xY,
                      groupLabel: "Curve From",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 3),
                .init(type: .xY,
                      groupLabel: "Curve To",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 5)
            ])
        case .output:
            return [.init(type: .readOnly,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex)]
        }
        
    case .singleDropdown:
        return [.init(type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .textFontDropdown:
        // TODO: Can keep using .dropdown ?
        return [.init(type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .bool:
        return [.init(type: .bool,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .asyncMedia:
        return [.init(type: .asyncMedia,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .number:
        return [.init(type: .number,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .string:
        return [.init(type: .string,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .layerDimension:
        return [.init(type: .layerDimension,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .pulse:
        return [.init(type: .pulse,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .color:
        return [.init(type: .color,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .json:
        return [.init(type: .json,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .assignedLayer:
        return [.init(type: .assignedLayer,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .pinTo:
        return [.init(type: .pinTo,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .anchoring:
        return [.init(type: .anchoring,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .readOnly:
        return [.init(type: .readOnly,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
        
    case .spacing:
        return [.init(type: .spacing,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex)]
    }
}

//extension Array where Element: FieldGroupTypeViewModel<InputFieldViewModel> {
extension NodeRowViewModel {
    @MainActor
    func createFieldValueTypes(initialValue: PortValue,
                               nodeIO: NodeIO,
                               unpackedPortParentFieldGroupType: FieldGroupType?,
                               unpackedPortIndex: Int?,
                               importedMediaObject: StitchMediaObject?) {

        self.fieldValueTypes = getFieldValueTypes(initialValue: initialValue,
                                                  nodeIO: nodeIO,
                                                  unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                  unpackedPortIndex: unpackedPortIndex,
                                                  importedMediaObject: importedMediaObject)

        
        self.fieldValueTypes.forEach { fieldValueType in
            fieldValueType.fieldObservers.forEach {
                guard let rowViewModel = self as? Self.FieldType.NodeRowType else {
                    fatalErrorIfDebug()
                    return
                }
                
                $0.rowViewModelDelegate = rowViewModel
            }
        }

        self.updateAllFields(with: initialValue,
                             nodeIO: nodeIO,
                             importedMediaObject: importedMediaObject)
    }
    
    // NOTE: ONLY ACTUALLY USED FOR INITIALIZATION OF FIELD VALUES ?
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

