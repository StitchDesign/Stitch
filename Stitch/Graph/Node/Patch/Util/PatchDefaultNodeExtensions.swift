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
    var defaultOutputs: PortValuesList {
        self.defaultNode(id: .init(),
                         position: .zero,
                         zIndex: .zero,
                         graphDelegate: nil)?
            .outputs ?? []
    }

    // called when we first place the patch on the graph
    // so we decide both the default port values AND the default user-visible-type
    @MainActor
    func defaultNode(id: NodeId, // = NodeId(),
                     position: CGSize,
                     zIndex: Double,
                     // TODO: separate 'first creation of node' from 'recreation of node via schema'
                     //                     firstCreation: Bool = true,
                     graphTime: TimeInterval = .zero,
                     graphDelegate: GraphDelegate?) -> NodeViewModel? {

        // Preferred newer method for node creation
        if let GraphNodeType = NodeKind.patch(self).graphNode {
            return GraphNodeType.createViewModel(id: id,
                                                 position: position.toCGPoint,
                                                 zIndex: zIndex,
                                                 graphDelegate: graphDelegate)
        }

        var node: PatchNode

        switch self {
        case .add:
            node = addPatchNode(nodeId: id, position: position, zIndex: zIndex)
        case .convertPosition:
            node = convertPositionNode(nodeId: id, position: position, zIndex: zIndex)
        case .multiply:
            node = multiplyPatchNode(id: id, position: position, zIndex: zIndex)
        case .divide:
            node = dividePatchNode(id: id, position: position, zIndex: zIndex)
        case .optionPicker:
            node = optionPickerPatchNode(id: id, nodePosition: position, nodeZIndex: zIndex)
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
        //        case .soundKit:
        //            node = soundKitNode(id: id, position: position, zIndex: zIndex)
        case .curve:
            node = curveNode(id: id, position: position, zIndex: zIndex)
        case .cubicBezierCurve:
            node = cubicBezierCurveNode(id: id, position: position, zIndex: zIndex)
        case .loopBuilder:
            return nil
        case .not:
            node = notNode(id: id, position: position, zIndex: zIndex)
        case .transition:
            node = transitionNode(id: id, position: position, zIndex: zIndex)
        case .speaker:
            node = speakerNode(id: id, position: position, zIndex: zIndex)
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
        case .clip:
            node = clipNode(id: id, position: position, zIndex: zIndex)
        case .max:
            node = maxNode(id: id, position: position, zIndex: zIndex)
        case .absoluteValue:
            node = absoluteValueNode(id: id, position: position, zIndex: zIndex)
        case .round:
            node = roundNode(id: id, position: position, zIndex: zIndex)
        case .progress:
            node = progressNode(id: id, position: position, zIndex: zIndex)
        case .reverseProgress:
            node = reverseProgressNode(id: id, position: position, zIndex: zIndex)
        case .wirelessReceiver:
            node = wirelessReceiverNode(id: id, position: position, zIndex: zIndex)
        case .wirelessBroadcaster:
            node = wirelessBroadcasterNode(id: id, position: position, zIndex: zIndex)
        case .rgba:
            node = rgbaNode(id: id, position: position, zIndex: zIndex)
        case .lessThanOrEqual:
            node = lessThanOrEqualPatchNode(id: id, position: position, zIndex: zIndex)
        case .equals:
            node = equalsPatchNode(id: id, position: position, zIndex: zIndex)
        case .arcTan2:
            node = arcTan2Node(id: id, position: position, zIndex: zIndex)
        case .sine:
            node = sineNode(id: id, position: position, zIndex: zIndex)
        case .cosine:
            node = cosineNode(id: id, position: position, zIndex: zIndex)
        case .soulver:
            node = soulverNode(id: id, position: position, zIndex: zIndex)
        case .optionEquals:
            node = optionEqualsNode(id: id, position: position, zIndex: zIndex)
        case .subtract:
            node = subtractNode(id: id, position: position, zIndex: zIndex)
        case .squareRoot:
            node = squareRootNode(id: id, position: position, zIndex: zIndex)
        case .length:
            node = lengthNode(id: id, position: position, zIndex: zIndex)
        case .min:
            node = minNode(id: id, position: position, zIndex: zIndex)
        case .power:
            node = powerNode(id: id, position: position, zIndex: zIndex)
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
        case .loopOptionSwitch:
            node = loopOptionSwitchNode(id: id, position: position, zIndex: zIndex)
        case .loopRemove:
            node = loopRemoveNode(id: id, position: position, zIndex: zIndex)
        case .loopReverse:
            node = loopReverseNode(id: id, position: position, zIndex: zIndex)
        case .loopShuffle:
            node = loopShuffleNode(id: id, position: position, zIndex: zIndex)
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
            // Shouldn't happen
            fatalErrorIfDebug()
            return nil
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
        
        if let graph = graphDelegate,
           let document = graphDelegate?.documentDelegate {
            node.initializeDelegate(graph: graph,
                                    document: document)
        }

        return node
    }
}
