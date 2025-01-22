//
//  ARRaycastingNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/26/23.
//

import Foundation
import StitchSchemaKit
@preconcurrency import ARKit
import RealityKit
import SwiftUI

extension Plane: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.plane
    }

    var targetAlignment: ARRaycastQuery.TargetAlignment {
        switch self {
        case .any:
            return .any
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        }
    }

    var display: String {
        switch self {
        case .any:
            return "Any"
        case .horizontal:
            return "Horizontal"
        case .vertical:
            return "Vertical"
        }
    }
}

struct ARRaycastingNode: PatchNodeDefinition {
    static let patch = Patch.arRaycasting
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        return .init(
            inputs: [
                .init(label: "Request", staticType: .pulse),
                .init(defaultValues: [.bool(true)],
                      label: "Enabled",
                      isTypeStatic: true),
                .init(label: "Origin", staticType: .plane),
                .init(label: "X Offsest", staticType: .number),
                .init(label: "Y Offset", staticType: .number)
            ],
            outputs: [
                .init(label: "Transform", 
                      type: .media)
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        MediaEvalOpObserver()
    }
}

@MainActor
func arRayCastingEval(node: PatchNode) -> EvalResult {
    let graphTime = node.graphDelegate?.graphStepState.graphTime ?? .zero
    let defaultOutputs = node.defaultOutputs
    let arView = node.graphDelegate?.cameraFeed?.arView
        
    // Must be accessed on main thread
    let centerPoint = arView?.arView.center ?? .zero

    return node.loopedEval(MediaEvalOpObserver.self) { values, mediaObserver, loopIndex in
        // Needs to have AR view
        guard let arView = arView else {
            return node.defaultOutputs
        }
        
        guard let requestPulse = values.first?.getPulse,
              let isEnabled = values[safe: 1]?.getBool,
              isEnabled else {
            return defaultOutputs
        }

        let alignmentType = values[safe: 2]?.getAlignmentType ?? .horizontal
        let xOffset = values[safe: 3]?.getNumber ?? 0
        let yOffset = values[safe: 4]?.getNumber ?? 0
        let prevValue = values[safe: 5] ?? defaultTransformAnchor
        let didPulse = requestPulse.shouldPulse(graphTime)

        return mediaObserver.asyncMediaEvalOp(loopIndex: loopIndex,
                                              values: values,
                                              node: node) { [weak arView] in
            guard let arView = arView,
                  didPulse,
                  let raycastResult = await arView.makeRaycast(alignmentType: alignmentType.targetAlignment,
                                                               center: centerPoint,
                                                               x: Float(xOffset),
                                                               y: Float(yOffset)) else {
                log("Raycast query unsuccessful")
                return [prevValue]
            }
            
            let transform: StitchTransform = StitchTransform.init(positionX: Double(raycastResult.worldTransform.position.x),
                                                                  positionY: Double(raycastResult.worldTransform.position.y),
                                                                  positionZ: Double(raycastResult.worldTransform.position.z),
                                                                  scaleX: Double(raycastResult.worldTransform.scale.x),
                                                                  scaleY: Double(raycastResult.worldTransform.scale.y),
                                                                  scaleZ: Double(raycastResult.worldTransform.scale.z), 
                                                                  rotationX: Double(raycastResult.worldTransform.rotationInRadians.x),
                                                                  rotationY: Double(raycastResult.worldTransform.rotationInRadians.y),
                                                                  rotationZ: Double(raycastResult.worldTransform.rotationInRadians.z))
            
            return [.transform(transform)]
        }
    }
}

extension ARRaycastQuery.TargetAlignment: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let value = ARRaycastQuery.TargetAlignment(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid raw value for TargetAlignment")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
