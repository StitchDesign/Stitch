//
//  NodeRowViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

protocol NodeRowViewModel: AnyObject, Identifiable {
    var id: Self.ID { get set }
    
    // View-specific value that only updates when visible
    // separate propety for perf reasons:
    var activeValue: PortValue { get set }
    
    // Holds view models for fields
    var fieldValueTypes: FieldGroupTypeViewModelList { get set }
    
    var anchorPoint: CGPoint? { get set }
    
    var rowDelegate: NodeRowObserver? { get set }
}

extension NodeRowViewModel {
    @MainActor
    func initializeValues(rowDelegate: NodeRowObserver) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        
        self.activeValue = Self.getActiveValue(allLoopedValues: rowDelegate.allLoopedValues,
                                               activeIndex: activeIndex)
        self.fieldValueTypes = .init(initialValue: self.activeValue,
                                     coordinate: rowDelegate.id,
                                     nodeIO: rowDelegate.nodeIOType,
                                     importedMediaObject: nil)
    }
    
    @MainActor
    func didPortValuesUpdate(values: PortValues,
                             rowDelegate: NodeRowObserver) {
        let activeIndex = rowDelegate.nodeDelegate?.activeIndex ?? .init(.zero)
        let isLayerFocusedInPropertySidebar = rowDelegate.nodeDelegate?.graphDelegate?.layerFocusedInPropertyInspector == rowDelegate.id.nodeId
        
        let oldViewValue = self.activeValue // the old cached
        let newViewValue = Self.getActiveValue(allLoopedValues: values,
                                               activeIndex: activeIndex)
        let didViewValueChange = oldViewValue != newViewValue
        
        /*
         Conditions for forcing fields update:
         1. Is at time of initialization--used for layers, or
         2. Did values change AND visible in frame, or
         3. Is this an input for a layer node that is focused in the property sidebar?
         */
        let shouldUpdate = didViewValueChange || isLayerFocusedInPropertySidebar

        if shouldUpdate {
            self.activeValue = newViewValue

            // TODO: pass in media to here!
            self.activeValueChanged(oldValue: oldViewValue,
                                    newValue: newViewValue)
        }
    }
}

extension NodeRowViewModel {
    // TODO: return nil if outputs were empty (e.g. prototype has just been restarted) ?
    static func getActiveValue(allLoopedValues: PortValues,
                               activeIndex: ActiveIndex) -> PortValue {
        let adjustedIndex = activeIndex.adjustedIndex(allLoopedValues.count)
        guard let value = allLoopedValues[safe: adjustedIndex] else {
            // Outputs may be instantiated as empty
            //            fatalError()
            log("getActiveValue: could not retrieve index \(adjustedIndex) in \(allLoopedValues)")
            // See https://github.com/vpl-codesign/stitch/issues/5960
            return PortValue.none
        }

        return value
    }
}

final class InputNodeRowViewModel: NodeRowViewModel {
    var id: InputPortViewData
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList()
    var anchorPoint: CGPoint?
    weak var rowDelegate: NodeRowObserver?
    
    @MainActor
    init(id: InputPortViewData,
         activeValue: PortValue,
         rowDelegate: NodeRowObserver) {
        self.id = id
        self.rowDelegate = rowDelegate
        self.initializeValues(rowDelegate: rowDelegate)
    }
}

final class OutputNodeRowViewModel: NodeRowViewModel {
    var id: OutputPortViewData
    var activeValue: PortValue = .number(.zero)
    var fieldValueTypes = FieldGroupTypeViewModelList()
    var anchorPoint: CGPoint?
    weak var rowDelegate: NodeRowObserver?
    
    @MainActor
    init(id: OutputPortViewData,
         activeValue: PortValue,
         rowDelegate: NodeRowObserver) {
        self.id = id
        self.rowDelegate = rowDelegate
        self.initializeValues(rowDelegate: rowDelegate)
    }
}

