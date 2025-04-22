//
//  RowFieldsUIViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/22/25.
//

import Foundation

protocol RowFieldsUIViewModel: Observable, Identifiable, AnyObject, Sendable {
    // Needs GraphItemType, since could be for canvas or inspector
    var id: NodeRowViewModelId { get }
    
    @MainActor var cachedActiveValue: PortValue { get set }
    @MainActor var cachedFieldValueGroups: [FieldGroup] { get set } // fields
}
