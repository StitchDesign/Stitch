//
//  FieldViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

typealias InputFieldViewModels = [InputFieldViewModel]
typealias OutputFieldViewModels = [OutputFieldViewModel]

protocol FieldViewModel: AnyObject, Observable, Identifiable {
    associatedtype NodeRowType: NodeRowViewModel
    
    var fieldValue: FieldValue { get set }

    // A port has 1 to many relationship with fields
    var fieldIndex: Int { get set }

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    var fieldLabel: String { get set }

    // e.g. Layer's size-scenario is "Constrain Height",
    // so we "block out" the Height fields on the Layer: size.height, minSize.height, maxSize.height
    var isBlockedOut: Bool { get set }
    
    var rowViewModelDelegate: NodeRowType? { get set }
    
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: NodeRowType?)
}

@Observable
final class InputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var fieldIndex: Int
    var fieldLabel: String
    var isBlockedOut: Bool = false
    
    weak var rowViewModelDelegate: InputNodeRowViewModel?
    
    var fieldLabelIndex: Int {
        guard let rowViewModelDelegate = rowViewModelDelegate else {
            fatalErrorIfDebug()
            return fieldIndex
        }
        
        switch rowViewModelDelegate.id.portType {
        
        case .portIndex:
            // leverage patch node definition to get label
            return fieldIndex
            
        case .keyPath(let layerInputType):
            
            switch layerInputType.portType {
            case .packed:
                // if it is packed, then field index is correct,
                // so can use proper label list etc.
                return fieldIndex
                
            case .unpacked(let unpackedPortType):
                let index = unpackedPortType.rawValue
                return index
            }
        }
    }
    
    //
    var label: String {
        // leverage the node definition to get the proper label
        
        let fieldGroupType: FieldGroupType? = nil
        fieldGroupType!.labels
        
        fatalError()
        return ""
    }
    
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: InputNodeRowViewModel?) {
        self.fieldValue = fieldValue
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

@Observable
final class OutputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var fieldIndex: Int
    var fieldLabel: String
    var isBlockedOut: Bool = false
    
    weak var rowViewModelDelegate: OutputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: OutputNodeRowViewModel?) {
        self.fieldValue = fieldValue
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

extension FieldViewModel {
    var id: FieldCoordinate {
        return .init(rowId: self.rowViewModelDelegate?.id ?? .empty,
                     fieldIndex: self.fieldIndex)
    }
    
    var rowDelegate: Self.NodeRowType.RowObserver? {
        self.rowViewModelDelegate?.rowDelegate
    }
}


// i.e. `createFieldObservers`
extension Array where Element: FieldViewModel {
    
    /*
    I'm creating a field view model for an unpacked Size input's Height field
     
    with our fieldLabelIndex logic, we can get the index of 1
     
     pass down an enum, for handling how field indices:
     - normal case: patch node inputs, packed layer node inputs
     - unpacked layer input (field index FOR LABEL PURPOSES)
     
     also pass in a Size FieldGroupType
     */
    
    init(_ fieldGroupType: FieldGroupType,
         
         // Unpacked ports need special logic for grabbing their proper label
         // e.g. the `y-field` of an unpacked `Position` layer input would otherwise have a field group type of `number` and a field index of 0, resulting in no label at all
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         
         startingFieldIndex: Int,
         
         rowViewModel: Element.NodeRowType?) {
        
        // If this is a field for an unpacked layer input, we must look at the unpacked's parent label-list
        let labels = (unpackedPortParentFieldGroupType ?? fieldGroupType).labels
                
        // Default value still uses original, proper field group type
        let defaultValues = fieldGroupType.defaultFieldValues
        
        
        
        
        /*
         Maybe?
         
         When creating single field view model for unpacked Size input's Height field, pass in a PortValue.Size, but then chop down the defaultValues list to be only of length
         
         to chop down the defaultValues in the case of the Height field view model creation,
         switch on the enum and only grab the SPECIFIC INDEX 
         */
        
        self = defaultValues.enumerated().map { fieldIndex, fieldValue in
            
            let index = unpackedPortIndex ?? fieldIndex
            
            let fieldLabel = labels[safe: index]

            // Every field should have a label, even if just an empty string.
            if fieldLabel == nil {
                fatalErrorIfDebug()
            }
            
            return .init(fieldValue: fieldValue,
                         fieldIndex: startingFieldIndex + index,
                         fieldLabel: fieldLabel ?? "",
                         rowViewModelDelegate: rowViewModel)
        }
    }
}
