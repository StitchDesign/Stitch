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
    
    init(value: PortValue, // every field group is
        type: FieldGroupType,
         groupLabel: String? = nil,
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         startingFieldIndex: Int = 0,
//         rowViewModel: FieldType.NodeRowType? = nil) {
        
         // For us to pass in the delegate-reference
         rowViewModel: FieldType.NodeRowType?) {
        
        self.type = type
        self.groupLabel = groupLabel
        self.startingFieldIndex = startingFieldIndex
        self.fieldObservers = .init(
            value: value,
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
                                                   importedMediaObject: StitchMediaObject?,
                                                   rowViewModel: FieldType.NodeRowType?) -> [FieldGroupTypeViewModel<FieldType>] {
    
    let value = initialValue
    
    switch initialValue.getNodeRowType(nodeIO: nodeIO) {
        
    case .size:
        return [.init(value: value,
                      type: .hW,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .position:
        return [.init(value: value,
                      type: .xY,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .point3D:
        return [.init(value: value,
                      type: .xYZ,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .point4D:
        return [.init(value: value,
                      type: .xYZW,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .padding:
        return [.init(value: value,
                      type: .padding,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .shapeCommand(let shapeCommand):
        switch shapeCommand {
        case .closePath:
            return [.init(value: value,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          rowViewModel: rowViewModel)]
        case .lineTo: // i.e. .moveTo or .lineTo
            return [.init(value: value,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          rowViewModel: rowViewModel),
                    .init(value: value,
                          type: .xY,
                          groupLabel: "Point", // optional
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          // REQUIRED, else we get two dropdowns
                          startingFieldIndex: 1,
                          rowViewModel: rowViewModel)
            ]
        case .curveTo:
            return .init([
                .init(value: value,
                      type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel),
                .init(value: value,
                      type: .xY,
                      groupLabel: "Point",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 1,
                      rowViewModel: rowViewModel),
                .init(value: value,
                      type: .xY,
                      groupLabel: "Curve From",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 3,
                      rowViewModel: rowViewModel),
                .init(value: value,
                      type: .xY,
                      groupLabel: "Curve To",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 5,
                      rowViewModel: rowViewModel)
            ])
        case .output:
            return [.init(value: value,
                          type: .readOnly,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          rowViewModel: rowViewModel)]
        }
        
    case .singleDropdown:
        return [.init(value: value,
                      type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .textFontDropdown:
        // TODO: Can keep using .dropdown ?
        return [.init(value: value,
                      type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .bool:
        return [.init(value: value,
                      type: .bool,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .asyncMedia:
        return [.init(value: value,
                      type: .asyncMedia,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .number:
        return [.init(value: value,
                      type: .number,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .string:
        return [.init(value: value,
                      type: .string,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .layerDimension:
        return [.init(value: value,
                      type: .layerDimension,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .pulse:
        return [.init(value: value,
                      type: .pulse,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .color:
        return [.init(value: value,
                      type: .color,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .json:
        return [.init(value: value,
                      type: .json,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .assignedLayer:
        return [.init(value: value,
                      type: .assignedLayer,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .pinTo:
        return [.init(value: value,
                      type: .pinTo,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .anchoring:
        return [.init(value: value,
                      type: .anchoring,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .readOnly:
        return [.init(value: value,
                      type: .readOnly,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .spacing:
        return [.init(value: value,
                      type: .spacing,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
    }
}

//extension Array where Element: FieldGroupTypeViewModel<InputFieldViewModel> {
extension NodeRowViewModel {
    
    // Every place we use this, we seem to pass in a proper
    @MainActor
    func createFieldValueTypes(initialValue: PortValue,
                               nodeIO: NodeIO,
                               unpackedPortParentFieldGroupType: FieldGroupType?,
                               unpackedPortIndex: Int?,
                               importedMediaObject: StitchMediaObject?) {

        
        let rowViewModelDelegate = self as? Self.FieldType.NodeRowType
        
//        let fieldValueTypes: [FieldGroupTypeViewModel<Self.FieldType>] = getFieldValueTypes(
//            initialValue: initialValue,
//            nodeIO: nodeIO,
//            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
//            unpackedPortIndex: unpackedPortIndex,
//            importedMediaObject: importedMediaObject,
//            // it's ambiguous because it doesn't know what type the row view model is
//            rowViewModel: rowViewModelDelegate) //self as? Self.FieldType.NodeRowType)
        
        self.fieldValueTypes = getFieldValueTypes(
            initialValue: initialValue,
            nodeIO: nodeIO,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex,
            importedMediaObject: importedMediaObject,
            // it's ambiguous because it doesn't know what type the row view model is
            rowViewModel: rowViewModelDelegate) //self as? Self.FieldType.NodeRowType)

//        self.fieldValueTypes.forEach { fieldValueType in
//            fieldValueType.fieldObservers.forEach {
//                guard let rowViewModel = self as? Self.FieldType.NodeRowType else {
//                    fatalErrorIfDebug()
//                    return
//                }
//                
//                $0.rowViewModelDelegate = rowViewModel
//            }
//        }

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
        
        let fieldValuesList = portValue.createFieldValues(
            nodeIO: nodeIO,
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

