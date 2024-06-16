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

    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
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

extension String: Error {}
