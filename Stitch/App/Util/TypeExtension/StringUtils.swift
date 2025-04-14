//
//  StringUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// https://stackoverflow.com/a/39677704/7170123
extension String {
    func substring(from: Int) -> String {
        let fromIndex = self.index(self.startIndex, offsetBy: from)
        return String(self[fromIndex...])
    }
}

extension StitchStringValue {
    static let additionIdentity: StitchStringValue = .init("")
    
    static func + (lhs: StitchStringValue, rhs: StitchStringValue) -> StitchStringValue {
        let isLargeString = lhs.isLargeString || rhs.isLargeString
        let newString = lhs.string + rhs.string
        return .init(newString, isLargeString: isLargeString)
    }

    static func += (lhs: inout StitchStringValue, rhs: StitchStringValue) {
        lhs = lhs + rhs
    }
}

struct StringIdentifiable: Identifiable {
    var rawValue: String
    
    var id: String { rawValue }
}
