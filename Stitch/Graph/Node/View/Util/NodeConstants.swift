//
//  NodeConstants.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import RealityKit
import StitchSchemaKit

// fka `NODE_CORNER_RADIUS`
let CANVAS_ITEM_CORNER_RADIUS: CGFloat = 12

// How much of the input-entry/output-exit 'port dot' is shown?
let PORT_VISIBLE_LENGTH: CGFloat = 16

// How tall is a given input or output?
let NODE_ROW_HEIGHT: CGFloat = 12

let NODE_TITLE_HEIGHT = NODE_ROW_HEIGHT + 8

let SPACING_BETWEEN_NODE_ROWS: CGFloat = NODE_ROW_HEIGHT

// Spacing between inputs and outputs in a node
// let NODE_BODY_SPACING: CGFloat = 56
let NODE_BODY_SPACING: CGFloat = 24

// Common spacing between port-entry, label-entry, value-entry etc.
// let NODE_COMMON_SPACING: CGFloat = 4
let NODE_COMMON_SPACING: CGFloat = 8

let NODE_BODY_PADDING: CGFloat = 8

let VALUE_BUTTON_WIDTH: CGFloat = 12

// ColorPicker on Catalyst uses a longer rectangle,
// vs circle on iPad.
let VALUE_BUTTON_CATALYST_COLOR_WIDTH: CGFloat = 48 // 66 // 30
let VALUE_BUTTON_CATALYST_COLOR_HEIGHT: CGFloat = 24

let CATALYST_COLOR_VALUE_BUTTON_SIZE: CGSize = CGSize(
    width: VALUE_BUTTON_CATALYST_COLOR_WIDTH,
    height: VALUE_BUTTON_CATALYST_COLOR_HEIGHT)

let TEXT_FIELD_MIN_WIDTH: CGFloat = 12

let DEFAULT_TRANSFORM_MATRIX = Transform.createMatrix(
    positionX: 0,
    positionY: 0,
    positionZ: 0,
    scaleX: 0.01,
    scaleY: 0.01,
    scaleZ: 0.01,
    rotationX: 0,
    rotationY: 0,
    rotationZ: 0,
    rotationReal: 1)

let DEFAULT_TRANSFORM_MATRIX_ANCHOR = Transform.createMatrix(
    positionX: 0,
    positionY: 0,
    positionZ: 0,
    scaleX: 1,
    scaleY: 1,
    scaleZ: 1,
    rotationX: 0,
    rotationY: 0,
    rotationZ: 0,
    rotationReal: 1)


let DEFAULT_STITCH_TRANSFORM: StitchTransform = StitchTransform.init(positionX: 0,
                                                                     positionY: 0,
                                                                     positionZ: 0,
                                                                     scaleX: 1,
                                                                     scaleY: 1, 
                                                                     scaleZ: 1,
                                                                     rotationX: 0,
                                                                     rotationY: 0,
                                                                     rotationZ: 0)
