//
//  SwiftUItoStitch.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/25.
//

import SwiftUI

protocol FromSwiftUIViewToStitch: Encodable {
    associatedtype T
    
    // nil if ViewConstructor could not be turned into Stitch concepts
    //    var toStitch: (
    //        Layer?, // nil e.g. for ScrollView, which contributes custom-values but not own layer
    //        [ValueOrEdge]
    //    )? { get }
    
    static func from(_ args: [SyntaxViewArgumentData],
                     viewName: SyntaxViewName) -> T?
    
    // TODO: this property is incorrect -- some SwiftUI views like ScrollView may not become a Layer
    var layer: AIGraphData_V0.Layer { get }
    
    func createCustomValueEvents() throws -> [ASTCustomInputValue]
}

/// View modifiers who may pack or unapck their portvalue data.
protocol PortValuesPackModifiable: FromSwiftUIViewModifierToStitch {
    static var layerInputPort: LayerInputPort { get }
    
    static var nodeType: NodeType { get }
    
    init(args: [SyntaxViewModifierArgumentType])
    
    var args: [SyntaxViewModifierArgumentType] { get }
}

extension PortValuesPackModifiable {
    func createCustomValueEvents() throws -> [LayerPortDerivation] {
        // Handle each argument argument
        let layerPortEvents: [LayerPortDerivationType] = try self.args.flatMap {
            try $0.derivePortValues()
        }
        
        let parsedValues = try layerPortEvents.compactMap { event -> PortValue? in
            guard let valueDesc = event.value else { return nil }
            return try PortValue(from: valueDesc)
        }
        
        // If one of the parsed events isn't a value, then there's at least one state ref, and we should return an unpacked scenario
        guard layerPortEvents.count == parsedValues.count else {
            let unpackedPortEvents = try layerPortEvents
                .createUnpackedEvents(layerInputPort: Self.layerInputPort)
            return unpackedPortEvents
        }
        
        // Packed scenarios--either return the only argument or pack up multiple
        if layerPortEvents.count == 1,
           let firstPortEvent = layerPortEvents.first {
            return [
                .init(input: Self.layerInputPort,
                      inputData: firstPortEvent)
            ]
        }
        
        // Pack up multiple values
        guard let packedValue = parsedValues.pack(type: Self.nodeType) else {
            fatalErrorIfDebug()
            let unpackedPortEvents = try layerPortEvents
                .createUnpackedEvents(layerInputPort: Self.layerInputPort)
            return unpackedPortEvents
        }
        
        return [
            .init(input: Self.layerInputPort,
                  value: packedValue)
        ]
    }
    
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> Self? {
        self.init(args: arguments.map(\.value))
    }
}
