//
//  PortValueEnum.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/15/24.
//

import Foundation
import StitchSchemaKit


// TODO: generic implementations?
protocol PortValueEnum: Equatable, CaseIterable {
    static var portValueTypeGetter: PortValueTypeGetter<Self> { get }
}

typealias PortValueTypeGetter<T> = (T) -> PortValue

extension PortValueEnum {
    static var choices: PortValues {
        self.allCases.map(portValueTypeGetter)
    }
    
    static func fromNumber(_ n: Double) -> PortValue {
        Self.fromNumber(int: Int(n))
    }
    
    static func fromNumber(int: Int) -> PortValue {
        portValueEnumCase(from: int, with: self.choices)
    }
}


func portValueEnumCase(from number: Int, with choices: PortValues) -> PortValue {
    
#if DEBUG || DEV_DEBUG
    // `CaseIterable.allCases` can't actually be empty
    let defaultValue = choices.first!.defaultFalseValue
#else
    let defaultValue = choices.first?.defaultFalseValue ?? .number(.zero)
#endif
    
    let i = getNumberBetween(value: number,
                             min: 0,
                             max: choices.count - 1)
    
    return choices[safe: i] ?? defaultValue
}
