//
//  TextTrimNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

struct TrimTextPatchNode: PatchNodeDefinition {
    static let patch = Patch.trimText
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.string(.init(""))],
                    label: "Text"
                ),
                .init(
                    defaultValues: [numberDefaultFalse],
                    label: "Position"
                ),
                .init(
                    defaultValues: [numberDefaultFalse],
                    label: "Length"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .string
                )
            ]
        )
    }
}


// https://origami.design/documentation/patches/builtin.textsubstring
// https://stackoverflow.com/questions/39677330/how-does-string-substring-work-in-swift
@MainActor
func trimTextEval(inputs: PortValuesList,
                  outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let text: String = values[safe: 0]?.getString?.string ?? .empty
        var position: Int = Int(values[safe: 1]?.getNumber ?? .zero)
        let length: Int = Int(values[safe: 2]?.getNumber ?? .zero)
        
        if position > (text.count - 1) {
            return .string(.init(""))
        } else {
            // Treat negative position as 0th index
            if position < 0 {
                position = 0
            }
            
            let newSub = text
                .substring(from: position)
                .prefix(length)
            
            return .string(StitchStringValue(String(newSub)))
        }
    }

    return resultsMaker(inputs)(op)
}
