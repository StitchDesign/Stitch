//
//  GraphSetters.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/25.
//

import Foundation

protocol GraphSetter {
     @MainActor var shouldResortPreviewLayers: Bool { get set }
}

extension GraphState: GraphSetter { }
