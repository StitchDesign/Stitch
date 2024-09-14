//
//  FieldCoercers.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ShapeCommand {

    // TODO: should access previousValues for a given commandType
    func convert(to: ShapeCommandType) -> ShapeCommand {
        switch to {
        case .closePath:
            return .closePath
        case .moveTo:
            return .moveTo(point: self.getPoint ?? .zero)
        case .lineTo:
            return .lineTo(point: self.getPoint ?? .zero)
        case .curveTo:
            return .curveTo(curveFrom: self.getCurveFrom ?? .zero,
                            point: self.getPoint ?? .zero,
                            curveTo: self.getCurveTo ?? .zero)
        }
    }

    func updatePositionForField(_ position: StitchPosition,
                                _ fieldIndex: Int) -> ShapeCommand {
        switch self {

        case .closePath:
            return self // no change, because not possible to edit

        case .lineTo:
            return .lineTo(point: position.toPathPoint)

        case .moveTo:
            return .moveTo(point: position.toPathPoint)

        case .curveTo(let curveFrom,
                      let point,
                      let curveTo):

            // Field 0: dropdown
            // Fields 1-7 are 3 position fields
            if fieldIndex < 3 {
                return .curveTo(curveFrom: curveFrom,
                                point: position.toPathPoint,
                                curveTo: curveTo)
            } else if fieldIndex < 5 {
                return .curveTo(curveFrom: position.toPathPoint,
                                point: point,
                                curveTo: curveTo)
            } else {
                return .curveTo(curveFrom: curveFrom,
                                point: point,
                                curveTo: position.toPathPoint)
            }
        }
    }
}

extension PortValue {
    func parseInputEdit(fieldValue: FieldValue, fieldIndex: Int) -> PortValue {
        //    log("fieldsToVaue: fields: \(fields)")
        //    log("fieldsToVaue: parentValue: \(parentValue)")

        switch self {
        case .size(let layerSize):
            guard let newSize = sizeParent(layerSize, fieldIndex, fieldValue.stringValue) else {
                log("parseInputEdit error: unable to parse size.")
                return self
            }
            return .size(newSize)
            
        case .position(let position):
            guard let newPosition = positionParent(position, fieldIndex, fieldValue.stringValue) else {
                log("parseInputEdit error: unable to parse position")
                return self
            }
            return .position(newPosition)

        case .point3D(let point):
            guard let newPoint3D = point3DParent(point, fieldIndex, fieldValue.stringValue) else {
                log("parseInputEdit error: unable to parse point3D")
                return self
            }
            return .point3D(newPoint3D)

        case .point4D(let point):
            guard let newPoint4D = point4DParent(point, fieldIndex, fieldValue.stringValue) else {
                log("parseInputEdit error: unable to parse point4D")
                return self
            }
            return .point4D(newPoint4D)

        case .padding(let x):
            guard let newPadding = paddingParent(x, fieldIndex, fieldValue.stringValue) else {
                log("parseInputEdit error: unable to parse padding")
                return self
            }
            return .padding(newPadding)
            
        case .layerDimension:
            switch fieldValue.layerDimensionField {
            case .none:
                return .layerDimension(.number(.zero))
            case .some(let fieldValueNumber):
                return .layerDimension(fieldValueNumber.layerDimension)
            }

        case .shapeCommand(let shapeCommand):
            switch shapeCommand {
            case .closePath:
                // Not possible to edit
                return self
            case .lineTo(let point), .moveTo(let point), .curveTo(_, let point, _):
                // Position indexes are 0 or 1 but shape commands can have as many as 7
                // First field is always dropdown so we subtract 1 on a modulo function
                let positionFieldIndex = (fieldIndex - 1) % 2
                guard let position = positionParent(point.stitchPosition, positionFieldIndex, fieldValue.stringValue) else {
                    log("PortValue.parseInputEdit error: unable to create position")
                    return self
                }

                let newCommand = shapeCommand.updatePositionForField(position, fieldIndex)
                return .shapeCommand(newCommand)
            }

        default:
            return parseUpdate(self, fieldValue.stringValue)
        }
    }
}

func positionParent(_ position: StitchPosition,
                    _ fieldIndex: Int,
                    _ edit: String) -> StitchPosition? {

    let number = toNumber(edit)

    if let number = number {
        if fieldIndex == 0 {
            return CGPoint(x: number,
                           y: position.y)
        } else if fieldIndex == 1 {
            return CGPoint(x: position.x,
                           y: number)
        } else {
            fatalError() // we had valid edit but unexpected field index
        }
    }
    return nil // did not have a valid edit
}

func point3DParent(_ point3D: Point3D,
                   _ fieldIndex: Int,
                   _ edit: String) -> Point3D? {

    let number = toNumber(edit)

    if let number = number {
        if fieldIndex == 0 {
            return Point3D(x: number,
                           y: point3D.y,
                           z: point3D.z)
        } else if fieldIndex == 1 {
            return Point3D(x: point3D.x,
                           y: number,
                           z: point3D.z)
        } else if fieldIndex == 2 {
            return Point3D(x: point3D.x,
                           y: point3D.y,
                           z: number)
        } else {
            log("point3DParent: valid edit \(edit) but unexpected field index \(fieldIndex) ")
            return nil
        }
    }
    return nil // did not have a valid edit
}

func point4DParent(_ point4D: Point4D,
                   _ fieldIndex: Int,
                   _ edit: String) -> Point4D? {

    let number = toNumber(edit)

    if let number = number {
        if fieldIndex == 0 {
            return Point4D(x: number,
                           y: point4D.y,
                           z: point4D.z,
                           w: point4D.w)
        } else if fieldIndex == 1 {
            return Point4D(x: point4D.x,
                           y: number,
                           z: point4D.z,
                           w: point4D.w)
        } else if fieldIndex == 2 {
            return Point4D(x: point4D.x,
                           y: point4D.y,
                           z: number,
                           w: point4D.w)
        } else if fieldIndex == 3 {
            return Point4D(x: point4D.x,
                           y: point4D.y,
                           z: point4D.z,
                           w: number)
        } else {
            log("point4DParent: valid edit \(edit) but unexpected field index \(fieldIndex) ")
            return nil
        }
    }
    return nil // did not have a valid edit
}

// Put in namespace
let PADDING_TOP_FIELD_INDEX = 0
let PADDING_RIGHT_FIELD_INDEX = 1
let PADDING_BOTTOM_FIELD_INDEX = 2
let PADDING_LEFT_FIELD_INDEX = 3

//let PADDING_TOP_FIELD_LABEL = "T"
//let PADDING_RIGHT_FIELD_LABEL = "R"
//let PADDING_BOTTOM_FIELD_LABEL = "B"
//let PADDING_LEFT_FIELD_LABEL = "L"

// TODO: support long vs short labels for individual fields in a multifield input
let PADDING_TOP_FIELD_LABEL = "Top"
let PADDING_RIGHT_FIELD_LABEL = "Right"
let PADDING_BOTTOM_FIELD_LABEL = "Bottom"
let PADDING_LEFT_FIELD_LABEL = "Left"


func paddingParent(_ padding: StitchPadding,
                   _ fieldIndex: Int,
                   _ edit: String) -> StitchPadding? {

    let number = toNumber(edit)

    if let number = number {
        if fieldIndex == PADDING_TOP_FIELD_INDEX {
            return StitchPadding(top: number,
                                 right: padding.right,
                                 bottom: padding.bottom,
                                 left: padding.left)
        } else if fieldIndex == PADDING_RIGHT_FIELD_INDEX {
            return StitchPadding(top: padding.top,
                                 right: number,
                                 bottom: padding.bottom,
                                 left: padding.left)
        } else if fieldIndex == PADDING_BOTTOM_FIELD_INDEX {
            return StitchPadding(top: padding.top,
                                 right: padding.right,
                                 bottom: number,
                                 left: padding.left)
        } else if fieldIndex == PADDING_LEFT_FIELD_INDEX {
            return StitchPadding(top: padding.top,
                                 right: padding.right,
                                 bottom: padding.bottom,
                                 left: number)
        } else {
            log("paddingParent: valid edit \(edit) but unexpected field index \(fieldIndex) ")
            return nil
        }
    }
    return nil // did not have a valid edit
}

// TODO: handle video
func sizeParent(_ size: LayerSize,
                _ fieldIndex: Int,
                _ edit: String) -> LayerSize? {

    if let dimension = LayerLengthDimension.fromUserEdit(edit: edit, fieldIndex: fieldIndex) {
        switch dimension.lengthDimension {
        case .width:
            return LayerSize(width: dimension.layerDimension,
                             height: size.height)
        case .height:
            return LayerSize(width: size.width,
                             height: dimension.layerDimension)
        }
    }
    
    return nil
}

struct LayerLengthDimension: Codable, Equatable {
    var layerDimension: LayerDimension
    var lengthDimension: LengthDimension
}

extension LayerLengthDimension {

    static func fromUserEdit(edit: String, fieldIndex: Int) -> Self? {
        
        guard let dimension = LayerDimension.fromUserEdit(edit: edit) else {
            return nil
        }
        
        if fieldIndex == WIDTH_FIELD_INDEX {
            return .init(layerDimension: dimension,
                         lengthDimension: .width)
        } else if fieldIndex == HEIGHT_FIELD_INDEX {
            return .init(layerDimension: dimension,
                         lengthDimension: .height)
        } else {
            // had valid edit but unexpected field index
            fatalErrorIfDebug()
            return nil
        }
    }
}
