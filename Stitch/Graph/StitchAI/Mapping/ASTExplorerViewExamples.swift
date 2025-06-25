//
//  ASTExplorerViewExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/25/25.
//

import Foundation


extension ASTExplorerView {
    static let codeExamples: [(title: String, code: String)] = [
        
        ("Rectangle", """
         Rectangle()
             .frame(width: 200, height: 100)
         """),
        
        ("Text", #"Text("salut")"#),
        
        ("Text with color", #"Text("salut").foregroundColor(Color.yellow).padding()"#),
        
        ("Image", #"Image(systemName: "star.fill")"#),
        
        ("ZStack Rectangles", """
         ZStack {
             Rectangle().fill(Color.blue)
             Rectangle().fill(Color.green)
         }
         """),
        
        ("Nested", """
         ZStack {
             Rectangle().fill(Color.blue)
             VStack {
                 Rectangle().fill(Color.green)
                 Rectangle().fill(Color.red)
             }
         }
         """),
        
        ("Nested with scale", """
         ZStack {
             Rectangle().fill(Color.blue)
             VStack {
                 Rectangle().fill(Color.green)
                 Rectangle().fill(Color.red)
             }
         }.scaleEffect(4)
         """),
    ]
    
    
    static let actionExamples: [(title: String, set: VPLLayerConceptOrderedSet)] = [
        ("Rectangle",  Self.actionExample1),
        ("Oval",       Self.actionExample2),
        ("Text",       Self.actionExample3),
        ("SF Symbol",  Self.actionExample4),
        ("Nested",  Self.actionExample5)
    ]
    
    static let actionExample1: VPLLayerConceptOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .rectangle, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: "Color.red")),
            .layerInputSet(.init(id: id, input: .opacity, value: "0.5")),
            .layerInputSet(.init(id: id, input: .scale, value: "2")),
        ]
    }()
    
    static let actionExample2: VPLLayerConceptOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .oval, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: "Color.blue")),
            .layerInputSet(.init(id: id, input: .opacity, value: "0.5")),
            .layerInputSet(.init(id: id, input: .scale, value: "2")),
        ]
    }()
    
    static let actionExample3: VPLLayerConceptOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .text, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: "Color.green")),
            .layerInputSet(.init(id: id, input: .zIndex, value: "88")),
            .layerInputSet(.init(id: id, input: .clipped, value: "true")),
            .layerInputSet(.init(id: id, input: .scale, value: "2")),
        ]
    }()
    
    static let actionExample4: VPLLayerConceptOrderedSet = {
        let id = UUID()
        return [
            .layer(.init(id: id, name: .sfSymbol, children: [])),
            .layerInputSet(.init(id: id, input: .color, value: "Color.green")),
            .layerInputSet(.init(id: id, input: .sfSymbol, value: "star.fill")),
            .layerInputSet(.init(id: id, input: .scale, value: "2")),
        ]
    }()
    
    static let actionExample5: VPLLayerConceptOrderedSet = {
        let id = UUID()
        let idChild = UUID()
        let childLayer = VPLLayer(id: idChild, name: .sfSymbol, children: [])
        return [
            .layer(.init(id: id, name: .group, children: [childLayer])),
            .layer(childLayer),
            .layerInputSet(.init(id: idChild, input: .color, value: "Color.green")),
            .layerInputSet(.init(id: idChild, input: .sfSymbol, value: "star.fill")),
            .layerInputSet(.init(id: id, input: .scale, value: "2")),
        ]
    }()
    
}
