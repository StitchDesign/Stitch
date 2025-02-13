//
//  SerializationUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Encodable {
    // For avoiding ugly `do { try ... } catch { error in ...}` syntax blocks
    var encode: Result<Data, Error> {
        Result {
            try JSONEncoder().encode(self)
        }
    }
    
    func encodeToData() throws -> Data {
        let encoder = getStitchEncoder()
        return try encoder.encode(self)
    }
    
    func encodeToPrintableString() throws -> String {
        let data = try self.encodeToData()
        return try data.createPrintableJsonString()
    }
}
