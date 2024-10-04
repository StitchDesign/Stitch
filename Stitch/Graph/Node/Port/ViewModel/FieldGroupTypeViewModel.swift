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
    
    init(fieldValues: FieldValues,
         type: FieldGroupType,
         groupLabel: String? = nil,
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         startingFieldIndex: Int = 0,
         rowViewModel: FieldType.NodeRowType?) {
                
        self.type = type
        self.groupLabel = groupLabel
        self.startingFieldIndex = startingFieldIndex
        self.fieldObservers = .createFieldViewModels(fieldValues: fieldValues,
                                                     fieldGroupType: type,
                                                     unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                     unpackedPortIndex: unpackedPortIndex,
                                                     startingFieldIndex: startingFieldIndex,
                                                     rowViewModel: rowViewModel)
    }
    
    /// Updates observer objects with latest data.
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

extension ShapeCommandFieldType {
    var fieldGroupTypes: [FieldGroupType] {
        switch self {
        case .closePath:
            return [.dropdown]
        case .lineTo: // i.e. .moveTo or .lineTo
            return [.dropdown, .xY]
        case .curveTo:
            return [.dropdown, .xY, .xY, .xY]
        case .output:
            return [.readOnly]
        }
    }
}

extension NodeRowType {
    
    var fieldGroupTypes: [FieldGroupType] {
        switch self {
        case .size:
            return [.hW]
        case .position:
            return [.xY]
        case .point3D:
            return [.xYZ]
        case .point4D:
            return [.xYZW]
        case .padding:
            return [.padding]
        case .shapeCommand(let shapeCommand):
            return shapeCommand.fieldGroupTypes
        case .bool:
            return [.bool]
        case .asyncMedia:
            return [.asyncMedia]
        case .number:
            return [.number]
        case .string:
            return [.string]
        case .layerDimension:
            return [.layerDimension]
        case .pulse:
            return [.pulse]
        case .color:
            return [.color]
        case .json:
            return [.json]
        case .assignedLayer:
            return [.assignedLayer]
        case .pinTo:
            return [.pinTo]
        case .anchoring:
            return [.anchoring]
        case .spacing:
            return [.spacing]
        case .singleDropdown, .textFontDropdown:
            return [.dropdown]
        case .readOnly:
            return [.readOnly]
        }
    }
    
    // TODO: must be some better way to get this information and/or tie it to `getFieldValueTypes`
    var getFieldGroupTypeForLayerInput: FieldGroupType {
        let fieldGroupTypes = self.fieldGroupTypes
        
        // LayerInput can never use ShapeCommand,
        // and so we should only have a single group of fields.
        assertInDebug(fieldGroupTypes.count == 1)
        
        guard let fieldGroupType = fieldGroupTypes.first else {
            fatalErrorIfDebug()
            return .number
        }
        
        return fieldGroupType
    }
}

// Creates the FieldViewModels with the correct data (based on PortValue) and correct row view model delegate reference
func getFieldValueTypes<FieldType: FieldViewModel>(value: PortValue,
                                                   nodeIO: NodeIO,
                                                   unpackedPortParentFieldGroupType: FieldGroupType?,
                                                   unpackedPortIndex: Int?,
                                                   importedMediaObject: StitchMediaObject?,
                                                   rowViewModel: FieldType.NodeRowType?) -> [FieldGroupTypeViewModel<FieldType>] {
    
    let fieldValuesList: [FieldValues] = value.createFieldValuesList(
        nodeIO: nodeIO,
        importedMediaObject: importedMediaObject)

    // All PortValue types except ShapeCommand use a single grouping of fields
    guard let fieldValuesForSingleFieldGroup = fieldValuesList.first else {
        fatalErrorIfDebug()
        return []
    }
    
    switch value.getNodeRowType(nodeIO: nodeIO) {
        
    case .size:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .hW,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .position:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .xY,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .point3D:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .xYZ,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .point4D:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .xYZW,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .padding:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .padding,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .shapeCommand(let shapeCommand):
        switch shapeCommand {
        case .closePath:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          rowViewModel: rowViewModel)]
        case .lineTo: // i.e. .moveTo or .lineTo
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          rowViewModel: rowViewModel),
                    .init(fieldValues: fieldValuesList[safe: 1] ?? [],
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
                .init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel),
                .init(fieldValues: fieldValuesList[safe: 1] ?? [],
                      type: .xY,
                      groupLabel: "Point",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 1,
                      rowViewModel: rowViewModel),
                .init(fieldValues: fieldValuesList[safe: 2] ?? [],
                      type: .xY,
                      groupLabel: "Curve From",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 3,
                      rowViewModel: rowViewModel),
                .init(fieldValues: fieldValuesList[safe: 3] ?? [],
                      type: .xY,
                      groupLabel: "Curve To",
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      startingFieldIndex: 5,
                      rowViewModel: rowViewModel)
            ])
        case .output:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .readOnly,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          rowViewModel: rowViewModel)]
        }
        
    case .singleDropdown:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .textFontDropdown:
        // TODO: Can keep using .dropdown ?
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .dropdown,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .bool:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .bool,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .asyncMedia:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .asyncMedia,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .number:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .number,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .string:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .string,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .layerDimension:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .layerDimension,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .pulse:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .pulse,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .color:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .color,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .json:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .json,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .assignedLayer:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .assignedLayer,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .pinTo:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .pinTo,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .anchoring:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .anchoring,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .readOnly:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .readOnly,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
        
    case .spacing:
        return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                      type: .spacing,
                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                      unpackedPortIndex: unpackedPortIndex,
                      rowViewModel: rowViewModel)]
    }
}

//extension Array where Element: FieldGroupTypeViewModel<InputFieldViewModel> {
extension NodeRowViewModel {
    func createFieldValueTypes(initialValue: PortValue,
                               nodeIO: NodeIO,
                               unpackedPortParentFieldGroupType: FieldGroupType?,
                               unpackedPortIndex: Int?,
                               importedMediaObject: StitchMediaObject?) {
        
        self.fieldValueTypes = getFieldValueTypes(
            value: initialValue,
            nodeIO: nodeIO,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex,
            importedMediaObject: importedMediaObject,
            rowViewModel: self as? Self.FieldType.NodeRowType)
    }
}
