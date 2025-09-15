//
//  PatchDefaultNodeExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Patch {
    @MainActor
    var defaultNodeType: NodeType? {
        self.defaultNode(id: .init(),
                         position: .zero,
                         zIndex: .zero,
                         graphDelegate: .createEmpty()).userVisibleType
    }

    // called when we first place the patch on the graph
    // so we decide both the default port values AND the default user-visible-type
    @MainActor
    func defaultNode(id: NodeId, // = NodeId(),
                     position: CGPoint,
                     zIndex: Double,
                     // TODO: separate 'first creation of node' from 'recreation of node via schema'
                     //                     firstCreation: Bool = true,
                     graphTime: TimeInterval = .zero,
                     graphDelegate: GraphState) -> NodeViewModel {

        // Preferred newer method for node creation
        if let GraphNodeType = PatchOrLayer.patch(self).graphNode {
            return GraphNodeType.createViewModel(id: id,
                                                 position: position,
                                                 zIndex: zIndex,
                                                 graphDelegate: graphDelegate)
        }

        var node: PatchNode

        switch self {
        // Converted nodes - these cases should not be reached anymore
        // since they now use the new PatchNodeDefinition system via graphNode
        // case .add: - now uses AddPatchNode
        // case .convertPosition: - now uses ConvertPositionPatchNode
        // case .multiply: - now uses MultiplyPatchNode
        // case .divide: - now uses DividePatchNode
        case .loop:
            node = loopStartNode(id: id, position: position, zIndex: zIndex)
        case .time:
            node = timePatchNode(id: id, position: position, zIndex: zIndex)
        case .deviceTime:
            node = deviceTimeNode(id: id, position: position, zIndex: zIndex)
        case .greaterOrEqual:
            node = greaterOrEqualPatchNode(id: id, position: position, zIndex: zIndex)
        case .restartPrototype:
            node = restartPrototypeNode(id: id, position: position, zIndex: zIndex)
        case .hslColor:
            node = hslColorNode(id: id, nodePosition: position, nodeZIndex: zIndex)
        case .or:
            node = orNode(id: id, position: position, zIndex: zIndex)
        case .and:
            node = andNode(id: id, position: position, zIndex: zIndex)
        case .optionSwitch:
            node = optionSwitchPatchNode(id: id, position: position, zIndex: zIndex)
        case .curve:
            node = curveNode(id: id, position: position, zIndex: zIndex)
        case .cubicBezierCurve:
            node = cubicBezierCurveNode(id: id, position: position, zIndex: zIndex)
        case .not:
            node = notNode(id: id, position: position, zIndex: zIndex)
        case .transition:
            node = transitionNode(id: id, position: position, zIndex: zIndex)
        // case .speaker: - this should be converted to use SpeakerPatchNode
        case .loopOverArray:
            node = loopOverArrayNode(id: id, position: position, zIndex: zIndex)
        case .setValueForKey:
            node = setValueForKeyNode(id: id, position: position, zIndex: zIndex)
        case .arrayCount:
            node = arrayCountNode(id: id, position: position, zIndex: zIndex)
        case .arrayJoin:
            node = arrayJoinNode(id: id, position: position, zIndex: zIndex)
        case .arrayReverse:
            node = arrayReverseNode(id: id, position: position, zIndex: zIndex)
        case .arraySort:
            node = arraySortNode(id: id, position: position, zIndex: zIndex)
        case .getKeys:
            node = getKeysNode(id: id, position: position, zIndex: zIndex)
        case .indexOf:
            node = indexOfNode(id: id, position: position, zIndex: zIndex)
        case .subarray:
            node = subarrayNode(id: id, position: position, zIndex: zIndex)
        case .deviceMotion:
            node = deviceMotionNode(id: id, position: position, zIndex: zIndex)
        case .deviceInfo:
            node = deviceInfoNode(id: id, position: position, zIndex: zIndex)
        // case .clip: - now uses ClipPatchNode
        // case .max: - now uses MaxPatchNode
        // case .mod: - now uses ModPatchNode
        // case .absoluteValue: - now uses AbsoluteValuePatchNode
        // case .round: - now uses RoundPatchNode
        case .rgba:
            node = rgbaNode(id: id, position: position, zIndex: zIndex)
        case .lessThanOrEqual:
            node = lessThanOrEqualPatchNode(id: id, position: position, zIndex: zIndex)
        case .equals:
            node = equalsPatchNode(id: id, position: position, zIndex: zIndex)
        // case .arcTan2: - now uses ArcTan2PatchNode
        // case .sine: - now uses SinePatchNode
        // case .cosine: - now uses CosinePatchNode
        case .soulver:
            node = soulverNode(id: id, position: position, zIndex: zIndex)
        case .optionEquals:
            node = optionEqualsNode(id: id, position: position, zIndex: zIndex)
        // case .subtract: - now uses SubtractPatchNode
        // case .squareRoot: - now uses SquareRootPatchNode
        // case .length: - now uses LengthPatchNode
        // case .min: - now uses MinPatchNode
        // case .power: - now uses PowerPatchNode
        case .equalsExactly:
            node = equalsExactlyPatchNode(id: id, position: position, zIndex: zIndex)
        case .greaterThan:
            node = greaterThanPatchNode(id: id, position: position, zIndex: zIndex)
        case .lessThan:
            node = lessThanPatchNode(id: id, position: position, zIndex: zIndex)
        case .colorToHSL:
            node = colorToHSLNode(id: id, position: position, zIndex: zIndex)
        case .colorToRGB:
            node = colorToRGBANode(id: id, position: position, zIndex: zIndex)
        case .colorToHex:
            node = colorToHexNode(id: id, position: position, zIndex: zIndex)
        case .hexColor:
            node = hexNode(id: id, position: position, zIndex: zIndex)
        case .splitText:
            node = splitTextNode(id: id, position: position, zIndex: zIndex)
        case .textEndsWith:
            node = textEndsWithNode(id: id, position: position, zIndex: zIndex)
        case .textLength:
            node = textLengthNode(id: id, position: position, zIndex: zIndex)
        case .textReplace:
            node = textReplaceNode(id: id, position: position, zIndex: zIndex)
        case .textStartsWith:
            node = textStartsWithNode(id: id, position: position, zIndex: zIndex)
        case .trimText:
            node = trimTextNode(id: id, position: position, zIndex: zIndex)
        case .textTransform:
            node = textTransformNode(id: id, position: position, zIndex: zIndex)
        case .dateAndTimeFormatter:
            node = dateAndTimeFormatterNode(id: id, position: position, zIndex: zIndex)
        case .optionSender:
            node = optionSenderNode(id: id, position: position, zIndex: zIndex)
        case .any:
            node = anyPatchNode(id: id, position: position, zIndex: zIndex)
        case .loopCount:
            node = loopCountNode(id: id, position: position, zIndex: zIndex)
        case .loopDedupe:
            node = loopDedupeNode(id: id, position: position, zIndex: zIndex)
        case .loopReverse:
            node = loopReverseNode(id: id, position: position, zIndex: zIndex)
        case .loopSum:
            node = loopSumNode(id: id, position: position, zIndex: zIndex)
        case .loopToArray:
            node = loopToArrayNode(id: id, position: position, zIndex: zIndex)
        case .runningTotal:
            node = runningTotalNode(id: id, position: position, zIndex: zIndex)
        case .loopFilter:
            node = loopFilterNode(id: id, position: position, zIndex: zIndex)
        case .triangleShape:
            node = triangleShapeNode(id: id, position: position, zIndex: zIndex)
        case .circleShape:
            node = circleShapeNode(id: id, position: position, zIndex: zIndex)
        case .ovalShape:
            node = ovalShapeNode(id: id, position: position, zIndex: zIndex)
        case .roundedRectangleShape:
            node = roundedRectangleShapeNode(id: id, position: position, zIndex: zIndex)
        case .union:
            node = unionNode(id: id, position: position, zIndex: zIndex)
        case .jsonToShape:
            node = jsonToShapeNode(id: id, position: position, zIndex: zIndex)
        case .shapeToCommands:
            node = ShapeToCommandsNode(id: id, position: position, zIndex: zIndex)
        case .commandsToShape:
            node = commandsToShapeNode(id: id, position: position, zIndex: zIndex)
        default:
            // This should not happen - all patches should either use the new PatchNodeDefinition system
            // or have a case in this switch statement
            fatalErrorIfDebug("defaultNode: could not create node for patch \(self)")
            // Create a minimal fallback node with one dummy input and output
            let inputs = toInputs(id: id, values: (nil, [.number(0)]))
            let outputs = toOutputs(id: id, offset: inputs.count, values: (nil, [.number(0)]))
            node = PatchNode(
                position: position,
                zIndex: zIndex,
                id: id,
                patchName: self,
                userVisibleType: .number,
                inputs: inputs,
                outputs: outputs
            )
        } // switch

        /*
         When first creating a brand new node (not recreating it from schema)
         we must ensure that the node's position and previousPosition
         line up against a top-left grid intersection
         when node is placed on graph.
         */
        //        if firstCreation {
        //            node = adjustNodePosition(node: node,
        //                                      center: position,
        //                                      // graphNodes is only for GroupNodes
        //                                      graphNodes: .empty)
        //        }
                
        if let document = graphDelegate.documentDelegate {
            node.initializeDelegate(graph: graphDelegate,
                                    document: document)
        }

        return node
    }
}
