//
//  NodeColor.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/1/22.
//

import SwiftUI
import StitchSchemaKit

let GRAY_NODE_TOP_COLOR: Color = Color(.grayNodeTop)

let GRAY_NODE_BOTTOM_COLOR: Color = Color(.grayNodeBottom)

let NODE_TAG_CAROUSEL_DARK_GRAY = Color(.stitchDarkGray)

let STITCH_PURPLE: Color = Color(.stitchPurple)

let STITCH_RED: Color = Color(.stitchRed)

let INPUT_FIELD_BACKGROUND: Color = Color(.inputFieldBackground)

let STITCH_DARK_GRAY: Color = Color(.stitchDarkGray)

let STITCH_PROJECT_TITLE_FONT_COLOR: Color = Color(.projectListFont)

let SEA_GREEN_NODE_TOP_COLOR: Color = Color(.seaGreenNodeBottom)

let SEA_GREEN_NODE_BOTTOM_COLOR: Color = Color(.seaGreenNodeBottom)

let SEA_GREEN_NODE_COLOR = NodeUIColor(
    title: SEA_GREEN_NODE_TOP_COLOR,
    body: SEA_GREEN_NODE_BOTTOM_COLOR)

let DEFAULT_PATCH_NODE_COLOR = NodeUIColor(
    title: GRAY_NODE_TOP_COLOR,
    body: GRAY_NODE_BOTTOM_COLOR)

let INTERACTION_PATCH_NODE_COLOR = DEFAULT_PATCH_NODE_COLOR

let GROUP_NODE_INPUT_BODY_COLOR: Color = Color(.groupNodeInputBody)

let GROUP_NODE_INPUT_COLOR = NodeUIColor(
    title: GROUP_NODE_INPUT_BODY_COLOR,
    body: GROUP_NODE_INPUT_BODY_COLOR)

let GROUP_NODE_OUTPUT_BODY_COLOR: Color = Color(.groupNodeOutputBody)

let GROUP_NODE_OUTPUT_COLOR = NodeUIColor(
    title: GROUP_NODE_OUTPUT_BODY_COLOR,
    body: GROUP_NODE_OUTPUT_BODY_COLOR)

let LAYER_NODE_COLOR = DEFAULT_PATCH_NODE_COLOR

let GROUP_NODE_COLOR = DEFAULT_PATCH_NODE_COLOR

let WIRELESS_RECEIVER_COLOR = NodeUIColor(
    title: WIRELESS_RECEIVER_MAGENTA,
    body: WIRELESS_RECEIVER_MAGENTA)

let WIRELESS_RECEIVER_MAGENTA = Color(.wirelessReceiverMagenta)

let LIGHT_BLUE: Color = Color(.stitchLightBlue)

let WIRELESS_BROADCASTER_COLOR = NodeUIColor(
    title: LIGHT_BLUE,
    body: LIGHT_BLUE)

struct NodeUIColor: Equatable, Hashable {
    let title: Color
    let body: Color

    static let commonNodeColor = Self.patchNode

    static let patchNode = DEFAULT_PATCH_NODE_COLOR
    static let interactionPatchNode = INTERACTION_PATCH_NODE_COLOR

    static let layerNode = LAYER_NODE_COLOR

    static let groupNode = GROUP_NODE_COLOR
    static let groupNodeInput = GROUP_NODE_INPUT_COLOR
    static let groupNodeOutput = GROUP_NODE_OUTPUT_COLOR

    static let wirelessReceiver = WIRELESS_RECEIVER_COLOR
    static let wirelessBroadcaster = WIRELESS_BROADCASTER_COLOR
}

func derivePatchNodeColor(for patch: Patch,
                          splitterType: SplitterType?) -> NodeUIColor {
    switch patch {
    case .wirelessReceiver:
        return NodeUIColor.wirelessReceiver
    case .wirelessBroadcaster:
        return NodeUIColor.wirelessBroadcaster
    default:
        if patch.isInteractionPatchNode {
            return INTERACTION_PATCH_NODE_COLOR
        } else if patch == .splitter,
                  let splitterType = splitterType,
                  splitterType == .input {
            return .groupNodeInput
        } else if patch == .splitter,
                  let splitterType = splitterType,
                  splitterType == .output {
            return .groupNodeOutput
        } else {
            return .patchNode
        }
    }
}

// https://www.ralfebert.com/ios/swift-uikit-uicolor-picker/
struct Color_Previews: PreviewProvider {
    static var previews: some View {
        LIGHT_BLUE
    }
}
