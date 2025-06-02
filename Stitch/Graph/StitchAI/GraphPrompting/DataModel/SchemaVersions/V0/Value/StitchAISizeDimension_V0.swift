//
//  StitchAISizeDimension_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAISizeDimension_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.StitchAISizeDimension
    // MARK: - end
    
    struct StitchAISizeDimension: StitchAIStringConvertable {
        var value: LayerDimension
    }
}

extension StitchAISizeDimension_V0.StitchAISizeDimension: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAISizeDimension_V0.StitchAISizeDimension) {
        fatalError()
    }
}
