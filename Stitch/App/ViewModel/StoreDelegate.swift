//
//  StoreDelegate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import SwiftUI

protocol StoreDelegate: AnyObject {
    var documentLoader: DocumentLoader { get }

    var previewRenderer: ImageRenderer<ThumbnailPreview>? { get set }
    
    @MainActor
    func saveUndoHistory(undoActions: [Action],
                         redoActions: [Action])
    
    @MainActor
    func saveUndoHistory(undoEvents: [@MainActor () -> ()],
                         redoEvents: [@MainActor () -> ()])
}
