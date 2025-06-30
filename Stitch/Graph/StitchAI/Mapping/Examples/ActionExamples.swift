//
//  MappingActionExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/26/25.
//

import Foundation
import SwiftUI


extension MappingExamples {
    
    static let actionExamples: [(title: String, set: VPLActionOrderedSet)] = [
        ("Rectangle",  Self.actionExample1),
        ("Oval",       Self.actionExample2),
        ("Text",       Self.actionExample3),
        ("SF Symbol",  Self.actionExample4),
        ("Nested",  Self.actionExample5)
    ]
    
    static let actionExample1: VPLActionOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .rectangle, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: PortValue.color(Color.red))),
            .layerInputSet(.init(id: id, input: .opacity, value: PortValue.number(0.5))),
            .layerInputSet(.init(id: id, input: .scale, value: PortValue.number(2))),
        ]
    }()
    
    static let actionExample2: VPLActionOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .oval, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: PortValue.color(Color.blue))),
            .layerInputSet(.init(id: id, input: .opacity, value: PortValue.number(0.5))),
            .layerInputSet(.init(id: id, input: .scale, value: PortValue.number(2))),
        ]
    }()
    
    static let actionExample3: VPLActionOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .text, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: PortValue.color(Color.green))),
            .layerInputSet(.init(id: id, input: .zIndex, value: .number(88))),
            .layerInputSet(.init(id: id, input: .clipped, value: .bool(true))),
            .layerInputSet(.init(id: id, input: .scale, value: PortValue.number(2))),
        ]
    }()
    
    static let actionExample4: VPLActionOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .sfSymbol, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: PortValue.color(Color.green))),
            .layerInputSet(.init(id: id, input: .sfSymbol, value: .string(.init("star.fill")))),
            .layerInputSet(.init(id: id, input: .scale, value: PortValue.number(2))),
        ]
    }()
    
    static let actionExample5: VPLActionOrderedSet = {
        let id = UUID()
        let idChild = UUID()
        let childLayer = VPLCreateNode(id: idChild, name: .sfSymbol, children: [])
        return [
            .layer(.init(id: id, name: .group, children: [childLayer])),
            .layer(childLayer),
            .layerInputSet(.init(id: idChild, input: .color, value: PortValue.color(Color.green))),
            .layerInputSet(.init(id: idChild, input: .sfSymbol, value: .string(.init("star.fill")))),
            .layerInputSet(.init(id: id, input: .scale, value: PortValue.number(2))),
        ]
    }()
    
}
