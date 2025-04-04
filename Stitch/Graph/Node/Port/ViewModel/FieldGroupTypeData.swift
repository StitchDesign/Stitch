//
//  FieldGroupTypeData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias FieldGroupTypeDataList = [FieldGroupTypeData]

struct FieldGroupTypeData: Identifiable {
    let id: FieldCoordinate
    let type: FieldGroupType
    // Only used for ShapeCommand cases? e.g. `.curveTo` has "PointTo", "CurveFrom" etc. 'groups of fields'
    let groupLabel: String?
    // Since this could be one of many in a node's row
    let startingFieldIndex: Int
    
    var fieldObservers: [FieldViewModel]

    @MainActor
    init(fieldValues: FieldValues,
         type: FieldGroupType,
         groupLabel: String? = nil,
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         startingFieldIndex: Int = 0,
         layerInput: LayerInputPort?,
         rowId: NodeRowViewModelId) {
        
        let fieldObservers: [FieldViewModel] = .createFieldViewModels(
            fieldValues: fieldValues,
            fieldGroupType: type,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex,
            startingFieldIndex: startingFieldIndex,
            layerInput: layerInput,
            rowId: rowId)
        
        assertInDebug(!fieldObservers.isEmpty)
        
        self.id = fieldObservers.first?.id ?? FieldCoordinate.fakeFieldCoordinate
        self.type = type
        self.groupLabel = groupLabel
        self.startingFieldIndex = startingFieldIndex
        self.fieldObservers = fieldObservers
    }
    
    /// Updates observer objects with latest data.
    @MainActor
    func updateFieldValues(fieldValues: FieldValues) {
        guard fieldValues.count == fieldObservers.count else {
            fatalErrorIfDebug("FieldGroupTypeData: updateFieldValues: non-equal count of field values to observer objects for \(type).")
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
            return [.wH]
        case .size3D:
            return [.wHL]
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
        case .singleDropdown, .textFontDropdown, .layerGroupOrientationDropdown, .layerGroupAlignment, .textAlignmentPicker, .textVerticalAlignmentPicker, .textDecoration:
            return [.dropdown]
        case .readOnly:
            return [.readOnly]
        case .anchorEntity:
            return [.anchorEntity]
        case .transform3D:
            return [.xYZ, .xYZ, .xYZ]
        }
    }
}

extension NodeRowViewModel {
    // Creates the FieldViewModels with the correct data (based on PortValue) and correct row view model delegate reference
    @MainActor
    func getFieldValueTypes(value: PortValue,
                            nodeIO: NodeIO,
                            unpackedPortParentFieldGroupType: FieldGroupType?,
                            unpackedPortIndex: Int?) -> [FieldGroupTypeData] {
        
        let rowViewModel = self
        let fieldValuesList: [FieldValues] = value.createFieldValuesList(
            nodeIO: nodeIO,
            rowViewModel: rowViewModel)
        
        
        let layerInput: LayerInputPort? = rowViewModel.rowDelegate?.id.layerInput?.layerInput
        let rowId: NodeRowViewModelId = rowViewModel.id
        
        // All PortValue types except ShapeCommand use a single grouping of fields
        guard let fieldValuesForSingleFieldGroup = fieldValuesList.first else {
            fatalErrorIfDebug()
            return []
        }
        
        switch value.getNodeRowType(nodeIO: nodeIO,
                                    layerInputPort: rowViewModel.id.layerInputPort,
                                    isLayerInspector: rowViewModel.isLayerInspector) {
            
        case .size:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .wH,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .size3D:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .wHL,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .position:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .xY,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .point3D:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .xYZ,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .point4D:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .xYZW,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .padding:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .padding,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .transform3D:
            // 3 groups of fields
            assertInDebug(fieldValuesList.count == 3)
            
            return [.init(fieldValues: fieldValuesList[0],
                          type: .xYZ,
                          groupLabel: "Position",
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId),
                    .init(fieldValues: fieldValuesList[1],
                          type: .xYZ,
                          groupLabel: "Scale",
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          startingFieldIndex: 3,
                          layerInput: layerInput,
                          rowId: rowId),
                    .init(fieldValues: fieldValuesList[2],
                          type: .xYZ,
                          groupLabel: "Rotation",
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          startingFieldIndex: 6,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .shapeCommand(let shapeCommand):
            switch shapeCommand {
            case .closePath:
                return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                              type: .dropdown,
                              unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                              unpackedPortIndex: unpackedPortIndex,
                              layerInput: layerInput,
                              rowId: rowId)]
            case .lineTo: // i.e. .moveTo or .lineTo
                return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                              type: .dropdown,
                              unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                              unpackedPortIndex: unpackedPortIndex,
                              layerInput: layerInput,
                              rowId: rowId),
                        .init(fieldValues: fieldValuesList[safe: 1] ?? [],
                              type: .xY,
                              groupLabel: "Point", // optional
                              unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                              unpackedPortIndex: unpackedPortIndex,
                              // REQUIRED, else we get two dropdowns
                              startingFieldIndex: 1,
                              layerInput: layerInput,
                              rowId: rowId)
                ]
            case .curveTo:
                return .init([
                    .init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId),
                    .init(fieldValues: fieldValuesList[safe: 1] ?? [],
                          type: .xY,
                          groupLabel: "Point",
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          startingFieldIndex: 1,
                          layerInput: layerInput,
                          rowId: rowId),
                    .init(fieldValues: fieldValuesList[safe: 2] ?? [],
                          type: .xY,
                          groupLabel: "Curve From",
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          startingFieldIndex: 3,
                          layerInput: layerInput,
                          rowId: rowId),
                    .init(fieldValues: fieldValuesList[safe: 3] ?? [],
                          type: .xY,
                          groupLabel: "Curve To",
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          startingFieldIndex: 5,
                          layerInput: layerInput,
                          rowId: rowId)
                ])
            case .output:
                return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                              type: .readOnly,
                              unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                              unpackedPortIndex: unpackedPortIndex,
                              layerInput: layerInput,
                              rowId: rowId)]
            }
            
        case .singleDropdown:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .textFontDropdown:
            // TODO: Can keep using .dropdown ?
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .dropdown,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .layerGroupOrientationDropdown:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .layerGroupOrientation,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .layerGroupAlignment:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .layerGroupAlignment,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .textAlignmentPicker:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .textAlignment,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .textVerticalAlignmentPicker:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .textVerticalAlignment,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .textDecoration:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .textDecoration,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .bool:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .bool,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .asyncMedia:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .asyncMedia,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .number:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .number,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .string:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .string,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .layerDimension:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .layerDimension,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .pulse:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .pulse,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .color:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .color,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .json:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .json,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .assignedLayer:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .assignedLayer,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .pinTo:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .pinTo,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .anchoring:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .anchoring,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .readOnly:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .readOnly,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .spacing:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .spacing,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
            
        case .anchorEntity:
            return [.init(fieldValues: fieldValuesForSingleFieldGroup,
                          type: .anchorEntity,
                          unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                          unpackedPortIndex: unpackedPortIndex,
                          layerInput: layerInput,
                          rowId: rowId)]
        }
    }
    
    @MainActor
    func createFieldValueTypes(initialValue: PortValue,
                               nodeIO: NodeIO,
                               unpackedPortParentFieldGroupType: FieldGroupType?,
                               unpackedPortIndex: Int?) -> [FieldGroupTypeData] {
        self.getFieldValueTypes(
            value: initialValue,
            nodeIO: nodeIO,
            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
            unpackedPortIndex: unpackedPortIndex)
    }
}
