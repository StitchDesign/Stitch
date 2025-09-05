//
//  StitchAISpacing_V1.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/8/25.
//

import SwiftUI
import StitchSchemaKit


enum StitchAISpacing_V1: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V1
    typealias StitchSpacing = StitchSpacing_V33.StitchSpacing
    typealias PreviousInstance = Self.StitchAISpacing
    // MARK: - end
    
    struct StitchAISpacing: StitchAIStringConvertable {
        var value: StitchSpacing
    }
}

extension StitchAISpacing_V1.StitchAISpacing: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: StitchAISpacing_V1.StitchAISpacing) {
        fatalError()
    }
}

// This is an extension of SSK V33's StitchSpacing
extension StitchSpacing: StitchAIValueStringConvertable {
    var encodableString: String {
        self.display
    }
    
    public init?(_ description: String) {
        guard let result = Self.fromUserEdit(edit: description) else {
            return nil
        }
        
        self = result
    }
}

// This extends the AI-specific wrapper type on SSK V33's StitchSpacing type
extension StitchAISpacing_V1.StitchAISpacing: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.value.display
    }
    
    var encodableString: String {
        self.description
    }
    
    public init?(_ description: String) {
        guard let result = StitchSpacing.fromUserEdit(edit: description) else {
            return nil
        }
        
        self.value = result
    }
}
