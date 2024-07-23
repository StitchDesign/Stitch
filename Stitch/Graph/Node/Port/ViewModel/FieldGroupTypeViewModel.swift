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
         startingFieldIndex: Int = 0,
         rowViewModel: FieldType.NodeRowType? = nil) {
        self.type = type
        self.groupLabel = groupLabel
        self.startingFieldIndex = startingFieldIndex
        self.fieldObservers = .init(type,
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

//extension Array where Element: FieldGroupTypeViewModel<InputFieldViewModel> {
extension NodeRowViewModel {
    @MainActor
    func createFieldValueTypes(initialValue: PortValue,
                               nodeIO: NodeIO,
                               importedMediaObject: StitchMediaObject?) {
        switch initialValue.getNodeRowType(nodeIO: nodeIO) {
        case .size:
            self.fieldValueTypes = [.init(type: .hW)]

        case .position:
            self.fieldValueTypes = [.init(type: .xY)]

        case .point3D:
            self.fieldValueTypes = [.init(type: .xYZ)]

        case .point4D:
            self.fieldValueTypes = [.init(type: .xYZW)]
            
        case .padding:
            self.fieldValueTypes = [.init(type: .padding)]

        case .shapeCommand(let shapeCommand):
            switch shapeCommand {
            case .closePath:
                self.fieldValueTypes = [.init(type: .dropdown)]
            case .lineTo: // i.e. .moveTo or .lineTo
                self.fieldValueTypes = [.init(type: .dropdown),
                        .init(type: .xY,
                              groupLabel: "Point", // optional
                              // REQUIRED, else we get two dropdowns
                              startingFieldIndex: 1)
                ]
            case .curveTo:
                self.fieldValueTypes = .init([
                    .init(type: .dropdown),
                    .init(type: .xY, groupLabel: "Point", startingFieldIndex: 1),
                    .init(type: .xY, groupLabel: "Curve From", startingFieldIndex: 3),
                    .init(type: .xY, groupLabel: "Curve To", startingFieldIndex: 5)
                ])
            case .output:
                self.fieldValueTypes = [.init(type: .readOnly)]
            }

        case .singleDropdown:
            self.fieldValueTypes = [.init(type: .dropdown)]

        case .textFontDropdown:
            // TODO: Can keep using .dropdown ?
            self.fieldValueTypes = [.init(type: .dropdown)]

        case .bool:
            self.fieldValueTypes = [.init(type: .bool)]

        case .asyncMedia:
            self.fieldValueTypes = [.init(type: .asyncMedia)]

        case .number:
            self.fieldValueTypes = [.init(type: .number)]

        case .string:
            self.fieldValueTypes = [.init(type: .string)]

        case .layerDimension:
            self.fieldValueTypes = [.init(type: .layerDimension)]

        case .pulse:
            self.fieldValueTypes = [.init(type: .pulse)]

        case .color:
            self.fieldValueTypes = [.init(type: .color)]

        case .json:
            self.fieldValueTypes = [.init(type: .json)]

        case .assignedLayer:
            self.fieldValueTypes = [.init(type: .assignedLayer)]

        case .anchoring:
            self.fieldValueTypes = [.init(type: .anchoring)]

        case .readOnly:
            self.fieldValueTypes = [.init(type: .readOnly)]
            
        case .spacing:
            self.fieldValueTypes = [.init(type: .spacing)]
        }
        
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
        
        if let node = self.nodeDelegate,
           let layerInput = self.rowDelegate?.id.portType.keyPath {
            node.blockOrUnlockFields(newValue: portValue,
                                     layerInput: layerInput)
        }
        
    }
}

