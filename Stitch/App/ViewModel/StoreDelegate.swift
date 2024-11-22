//
//  StoreDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation

protocol StoreDelegate: AnyObject {
    var documentLoader: DocumentLoader { get }

    @MainActor
    func saveUndoHistory(undoActions: [Action],
                         redoActions: [Action])
    
    @MainActor
    func saveUndoHistory(undoEvents: [@MainActor () -> ()],
                         redoEvents: [@MainActor () -> ()])
}
