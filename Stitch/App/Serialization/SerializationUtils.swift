//
//  SerializationUtils.swift
//  prototype
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
}
