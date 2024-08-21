//
//  CustomShape.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import NonEmpty
import SwiftyJSON

extension [ShapeAndRect] {

    // TODO: implement for all ShapeAndRect enum cases,
    // and thus return `[ShapeCommand]` instead of `[ShapeCommand]?`
    var fromShapeToShapeCommandLoop: [ShapeCommand]? {

        // A CustomShape may be the result of a shape union patch node,
        // and thus contain more than one simple `ShapeAndRect`.
        // When converting in `Shape to Commands` node,
        // we always take first shape in union.
        self
            // first shape in potential union
            .first?
            // for now we only convert ShapeAndRect.custom to commands
            .getCustom?
            // turn the list of JSONShapeCommands into ShapeCommands
            .map(\.asShapeCommand)
    }

    // for flattening a Shape to a single ShapeCommand
    var toShapeCommand: ShapeCommand? {
        // Note: SHapeAndRect.custom(JSONShapeCommands: [JSONShapeCommand])
        self.first?.getCustom?.first?.asShapeCommand

    }
}

extension CustomShape {
    var totalHeight: CGFloat {
        south - north
    }

    var totalWidth: CGFloat {
        east - west
    }

    func xScale(_ shapeLayerNodeSize: CGSize) -> CGFloat {
        shapeLayerNodeSize.width.abs/(totalWidth)
    }

    func yScale(_ shapeLayerNodeSize: CGSize) -> CGFloat {
        shapeLayerNodeSize.height.abs/(totalHeight)
    }

    var xOffset: CGFloat {
        var offset: CGFloat

        if east == west {
            offset = .zero
        } else {
            offset = abs(west + east) / 2
        }

        // "If the diff is westward, then move us eastward"
        if (west + east) < 0 {
            return offset.abs
        }
        // "If the diff is eastward, then move us westward"
        else {
            return -offset
        }
    }

    var yOffset: CGFloat {
        var offset: CGFloat

        if north == south {
            offset = .zero
        } else {
            offset = abs(north + south) / 2
        }

        if (north + south) < 0 {
            return offset.abs
        } else {
            return -offset
        }
    }
}

extension CustomShape {

    var asJSON: JSON {
        /*
         ShapeAndRect.toJSON produces a `{ path: [...] }` json;
         `flatten`ing them produces a json array like:
         [ { path: [command1, command2] }, { path: [command3] } ]

         ... whereas we want a json object like:
         { path: [command1, command2, command3] }
         */
        // TODO: properly handle the failure to create a JSON from a shape
        //        self.compactMap(\.toJSON).mergedIntoPath

        let paths: [PathCommands] = self.shapes.compactMap { (sr: ShapeAndRect) in
            switch sr {
            case .custom(let jsonShapeCommands):
                return jsonShapeCommands.asPathCommands
            default: // ignore .oval, .rectangle etc. for now
                return nil
            }
        }

        let mergedPath: PathCommands = paths.merge()

        if let data: Data = try? JSONEncoder().encode(mergedPath),
           let json: JSON = try? JSON(data: data) {
            return json
        }
        log("CustomShape: asJSON: failed to create json from shapes")
        return emptyJSONObject

    }
}

extension [PathCommands] {
    // Turn multiple PathCommands into a single PathCommand
    func merge() -> PathCommands {
        var result = PathCommands(path: [])
        for x in self {
            result.path += x.path
        }
        return result
    }
}

// -- MARK: DEFAULTS

extension CustomShape {
    static let triangleShapePatchNodeDefault = CustomShape(.triangle(.defaultTriangle))

    static let ovalShapePatchNodeDefault = CustomShape(.oval(.defaultOval))

    static let circleShapePatchNodeDefault = CustomShape(.circle(.defaultCircle))

    static let roundedRectangleShapePatchNodeDefault = CustomShape(.rectangle(CGRect.defaultRoundedRectangle))
}

extension CGRect {
    static let defaultOval = CGRect(origin: .zero,
                                    size: .init(width: 20,
                                                height: 20))

    // TODO: should just be `origin` and `radius`
    static let defaultCircle = CGRect(origin: .zero,
                                      // radius of 10 -> diameter of 20
                                      size: .init(width: 20,
                                                  height: 20))

    static let defaultRoundedRectangle = RoundedRectangleData(
        rect: CGRect(origin: .zero,
                     size: .init(width: 100,
                                 height: 100)),
        cornerRadius: 4)
}
