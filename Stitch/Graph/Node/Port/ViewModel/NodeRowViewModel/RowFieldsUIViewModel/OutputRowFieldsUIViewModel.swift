//
//  OutputRowFieldsUIViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/22/25.
//

import Foundation

@Observable
final class OutputRowFieldsUIViewModel: RowFieldsUIViewModel {
    let id: NodeRowViewModelId
    
    @MainActor var cachedActiveValue: PortValue
    @MainActor var cachedFieldValueGroups: [FieldGroup]
    
    @MainActor
    init(id: NodeRowViewModelId,
         cachedActiveValue: PortValue,
         cachedFieldValueGroups: [FieldGroup]) {
        self.id = id
        self.cachedActiveValue = cachedActiveValue
        self.cachedFieldValueGroups = cachedFieldValueGroups
    }
}

extension OutputNodeRowViewModel {
    @MainActor var cachedActiveValue: PortValue {
        get {
            self.fieldsUIViewModel.cachedActiveValue
        } set(newValue) {
            self.fieldsUIViewModel.cachedActiveValue = newValue
        }
    }
    
    @MainActor var cachedFieldValueGroups: [FieldGroup] {
        get {
            self.fieldsUIViewModel.cachedFieldValueGroups
        } set(newValue) {
            self.fieldsUIViewModel.cachedFieldValueGroups = newValue
        }
    }
}
