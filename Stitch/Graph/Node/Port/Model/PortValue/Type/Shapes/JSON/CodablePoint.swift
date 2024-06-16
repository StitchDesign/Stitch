//
//  CodablePoint.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/*
 PropertyWrappers in Swift:
 https://forums.swift.org/t/best-approach-for-codable-on-types-i-dont-own/28915/4
 https://www.swiftbysundell.com/articles/property-wrappers-in-swift/
 https://www.avanderlee.com/swift/property-wrappers/
 https://www.swift.org/blog/property-wrappers/
 https://www.donnywals.com/writing-custom-property-wrappers-for-swiftui/

 Manual encoding and decoding:
 https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
 */
@propertyWrapper
struct CodablePoint: Equatable {
    var wrappedValue: CGPoint
    enum CodingKeys: CodingKey { case x, y }
}

extension CodablePoint {
    init(_ point: CGPoint) {
        self.wrappedValue = point
    }
}

extension CodablePoint: Encodable {
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(wrappedValue.x, forKey: .x)
        try c.encode(wrappedValue.y, forKey: .y)
    }
}

extension CodablePoint: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.wrappedValue = .init()
        self.wrappedValue.x = try values.decode(CGFloat.self, forKey: .x)
        self.wrappedValue.y = try values.decode(CGFloat.self, forKey: .y)
    }
}
