////
////  MappingActionExamples.swift
////  Stitch
////
////  Created by Christian J Clampitt on 6/26/25.
////
//
//import Foundation
//import SwiftUI
//
//
//extension MappingExamples {
//    
//    static let actionExamples: [(title: String, set: VPLActionOrderedSet)] = [
//        ("Rectangle",  Self.actionExample1),
//        ("Oval",       Self.actionExample2),
//        ("Text",       Self.actionExample3),
//        ("SF Symbol",  Self.actionExample4),
//        ("Nested",  Self.actionExample5)
//    ]
//    
//    static let actionExample1: VPLActionOrderedSet = {
//        let id = UUID()
//        return [
//            .createNode(.init(id: id, name: .rectangle, children: [])),
//            .setInput(.init(id: id, input: .color, value: PortValue.color(Color.red))),
//            .setInput(.init(id: id, input: .opacity, value: PortValue.number(0.5))),
//            .setInput(.init(id: id, input: .scale, value: PortValue.number(2))),
//        ]
//    }()
//    
//    static let actionExample2: VPLActionOrderedSet = {
//        let id = UUID()
//        return [
//            .createNode(.init(id: id, name: .oval, children: [])),
//            .setInput(.init(id: id, input: .color, value: PortValue.color(Color.blue))),
//            .setInput(.init(id: id, input: .opacity, value: PortValue.number(0.5))),
//            .setInput(.init(id: id, input: .scale, value: PortValue.number(2))),
//        ]
//    }()
//    
//    static let actionExample3: VPLActionOrderedSet = {
//        let id = UUID()
//        return [
//            .createNode(.init(id: id, name: .text, children: [])),
//            .setInput(.init(id: id, input: .color, value: PortValue.color(Color.green))),
//            .setInput(.init(id: id, input: .zIndex, value: .number(88))),
//            .setInput(.init(id: id, input: .clipped, value: .bool(true))),
//            .setInput(.init(id: id, input: .scale, value: PortValue.number(2))),
//        ]
//    }()
//    
//    static let actionExample4: VPLActionOrderedSet = {
//        let id = UUID()
//        return [
//            .createNode(.init(id: id, name: .sfSymbol, children: [])),
//            .setInput(.init(id: id, input: .color, value: PortValue.color(Color.green))),
//            .setInput(.init(id: id, input: .sfSymbol, value: .string(.init("star.fill")))),
//            .setInput(.init(id: id, input: .scale, value: PortValue.number(2))),
//        ]
//    }()
//    
//    static let actionExample5: VPLActionOrderedSet = {
//        let id = UUID()
//        let idChild = UUID()
//        let childLayer = VPLCreateNode(id: idChild, name: .sfSymbol, children: [])
//        return [
//            .createNode(.init(id: id, name: .group, children: [childLayer])),
//            .createNode(childLayer),
//            .setInput(.init(id: idChild, input: .color, value: PortValue.color(Color.green))),
//            .setInput(.init(id: idChild, input: .sfSymbol, value: .string(.init("star.fill")))),
//            .setInput(.init(id: id, input: .scale, value: PortValue.number(2))),
//        ]
//    }()
//    
//}
