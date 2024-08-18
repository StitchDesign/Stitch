//
//  ShapeCommand.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/11/23.
//

import Foundation
import StitchSchemaKit

extension ShapeCommandType: PortValueEnum {
    var display: String {
        switch self {
        case .closePath:
            return "Close Path"
        case .lineTo:
            return "Line To"
        case .moveTo:
            return "Move To"
        case .curveTo:
            return "Curve To"
        }
    }

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.shapeCommandType
    }

    static let defaultFalseShapeCommandType: Self = .moveTo
}

// Needed so that we can encode CGPoint in the "{ x: 1, y: 2 }" format expected by path json arrays and shape commands
extension PathPoint {
    var asCGPoint: CGPoint {
        .init(x: x, y: y)
    }

    var asCGSize: CGSize {
        .init(width: x, height: y)
    }

    static let zero = PathPoint(x: 0, y: 0)
}

extension CGPoint {
    var toPathPoint: PathPoint {
        .init(x: x, y: y)
    }
}

extension CGSize {
    var toPathPoint: PathPoint {
        .init(x: width, y: height)
    }
}

extension ShapeCommand {
    var getShapeCommandType: ShapeCommandType {
        switch self {
        case .closePath:
            return .closePath
        case .moveTo:
            return .moveTo
        case .lineTo:
            return .lineTo
        case .curveTo:
            return .curveTo
        }
    }

    var dropdownLabel: String {
        switch self {
        case .closePath:
            return "Close Path"
        case .lineTo:
            return "Line To"
        case .moveTo:
            return "Move To"
        case .curveTo:
            return "Curve To"
        }
    }

    var getPoint: PathPoint? {
        switch self {
        case .closePath:
            return nil
        case .lineTo(let point):
            return point
        case .moveTo(let point):
            return point
        case .curveTo(_, let point, _):
            return point
        }
    }

    var getCurveFrom: PathPoint? {
        switch self {
        case .curveTo(let curveFrom, _, _):
            return curveFrom
        default:
            return nil
        }
    }

    var getCurveTo: PathPoint? {
        switch self {
        case .curveTo(_, _, let curveTo):
            return curveTo
        default:
            return nil
        }
    }

    static let defaultFalseShapeCommand: ShapeCommand = .defaultFalseMoveTo

    static let defaultFalseMoveTo: Self = .moveTo(point: .zero)
    static let defaultFalseLineTo: Self = .lineTo(point: .zero)
    static let defaultFalseCurveTo: Self = .curveTo(curveFrom: .zero, point: .zero, curveTo: .zero)

    var defaultFalseValue: Self {
        switch self {
        case .closePath:
            return .closePath
        case .moveTo:
            return .defaultFalseMoveTo
        case .lineTo:
            return .defaultFalseLineTo
        case .curveTo:
            return .defaultFalseCurveTo
        }
    }

}

extension PathPoint {
    var stitchPosition: StitchPosition {
        .init(x: self.x, y: self.y)
    }
}
