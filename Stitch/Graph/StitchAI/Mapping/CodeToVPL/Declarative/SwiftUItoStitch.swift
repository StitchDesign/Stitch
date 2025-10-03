//
//  SwiftUItoStitch.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/25.
//

import SwiftUI
import Foundation

protocol FromSwiftUIViewToStitch {
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
    
    // Creates complete LayerData with children and custom value events
    func createCustomValueEvents(
        childrenLayers: [CurrentAIGraphData.LayerData],
        nodeId: String,
        isStreaming: Bool
    ) throws -> CurrentAIGraphData.LayerData
}

/// View modifiers who may pack or unapck their portvalue data.
protocol PortValuesPackModifiable: FromSwiftUIViewModifierToStitch {
    static var layerInputPort: LayerInputPort { get }
    
    static var nodeType: NodeType { get }
    
    init(args: [SyntaxViewArgumentData])
    
    var args: [SyntaxViewArgumentData] { get }
}

extension PortValuesPackModifiable {
    func createCustomValueEvents(isStreaming: Bool) throws -> [LayerPortDerivation] {
        // Reorder arguments to match layer unpack ordering
        let layerPortEvents = try self.args
            .reorderUnapckedValues(varName: nil,
                                   viewEvent: nil,
                                   nodesDict: [:],
                                   nodeType: Self.nodeType,
                                   isStreaming: isStreaming)
        
        let parsedValues = layerPortEvents.compactMap { event -> PortValue? in
            guard let value = event.portData?.values?.first else { return nil }
            return value
        }
        
        // Packed scenarios--either return the only argument or pack up multiple
        if layerPortEvents.count == 1,
           let firstPortEvent = layerPortEvents.first {
            return [
                .init(input: Self.layerInputPort,
                      inputData: [firstPortEvent])
            ]
        }
        
        // If one of the parsed events isn't a value, then there's at least one state ref, and we should return an unpacked scenario
        guard layerPortEvents.count == parsedValues.count else {
            let unpackedPortEvents = try layerPortEvents
                .createUnpackedEvents(layerInputPort: Self.layerInputPort, isStreaming: isStreaming)
            return unpackedPortEvents
        }
        
        // Pack up multiple values
        guard let packedValue = parsedValues.pack(type: Self.nodeType,
                                                  isStreamingAIResponse: isStreaming) else {
            if !isStreaming {
                fatalErrorIfDebug()
            }
            let unpackedPortEvents = try layerPortEvents
                .createUnpackedEvents(layerInputPort: Self.layerInputPort, isStreaming: isStreaming)
            return unpackedPortEvents
        }
        
        return [
            .init(input: Self.layerInputPort,
                  value: packedValue)
        ]
    }

    static func from(_ arguments: [SyntaxViewArgumentData]) -> Self? {
        self.init(args: arguments)
    }
    
    // Required for protocol
    static func from(_ arguments: [SyntaxViewArgumentData],
                     modifierName: SyntaxViewModifierName) -> Self? {
        self.init(args: arguments)
    }
}
