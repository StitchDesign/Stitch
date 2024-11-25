//
//  CommentBoxData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/6/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias CommentBoxIdSet = Set<CommentBoxId>
typealias CommentBoxViewModels = [CommentBoxViewModel]

// struct CommentBoxId: Equatable, Identifiable, Codable, Hashable {
//    var id: UUID = .init()
//
//    static let fakeId: Self = .init()
// }

typealias CommentBoxId = UUID

// struct CommentBoxId: Equatable, Identifiable, Codable, Hashable {
//    var id: UUID = .init()
//
//    static let fakeId: Self = .init()
// }

extension CommentBoxId {
    static let fakeId: Self = .init()
}

extension CommentBoxesDict {
    func boxesForTraversalLevel(_ groupNodeId: UUID? = nil) -> CommentBoxViewModels {
        self.values.filter { $0.groupId == groupNodeId }
    }
}

extension CommentBoxViewModel: Identifiable {
    var titleHeight: CGFloat {

        let proposedHeight = title.heightWithConstrainedWidth(
            // How much space in which we have to place the text
            width: expansionBox.size.width - 32,
            // Approximate system size font ?
            // Differs for iPad vs. Catalyst?
            font: .systemFont(ofSize: 20)
        )

        let boxHeight = expansionBox.size.height
        let minTitleHeight = 60.0

        // Title area can never be taller than comment box's height
        if proposedHeight > boxHeight {
            return boxHeight
        }
        // Title area can never be less than ~40 pts tall
        else if proposedHeight < minTitleHeight {
            return minTitleHeight
        } else {
            return proposedHeight
        }
    }

    static let colorOptions: [Color] = [
        .yellow, .red, .orange, .green, .blue, .cyan, .indigo, .purple, .gray
    ]
}

extension String {
    func heightWithConstrainedWidth(width: CGFloat,
                                    font: UIFont) -> CGFloat {

        let constraintRect = CGSize(width: width,
                                    height: .greatestFiniteMagnitude)

        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [NSAttributedString.Key.font: font],
            context: nil)

        return boundingBox.height
    }
}

extension CommentBoxViewModel {
    @MainActor
    convenience init(zIndex: Double? = nil) {
        let color = Self.colorOptions.randomElement() ?? .blue
        
        self.init(color: color,
                  expansionBox: .init(expansionDirection: nil,
                                      size: .zero,
                                      startPoint: .zero,
                                      endPoint: .zero),
                  zIndex: zIndex ?? .zero)
    }
    
    // MARK: initializing comment box from a set of existing nodes
    @MainActor
    convenience init(zIndex: ZIndex,
                     scale: CGFloat, // graph zoom
                     nodes: [CanvasItemViewModel]) {

        let color = Self.colorOptions.randomElement() ?? .blue

        guard !nodes.isEmpty else {
            log("CommentBoxData: init: nodes were empty")

            self.init(zIndex: zIndex)
            return
        }
        
        guard let northNode = nodes.max(by: { n1, n2 in
            n1.position.y > n2.position.y
        }),
              let southNode = nodes.max(by: { n1, n2 in
                  n1.position.y < n2.position.y
              }),
              let eastNode = nodes.max(by: { n1, n2 in
                  n1.position.x < n2.position.x
              }),
              let westNode = nodes.max(by: { n1, n2 in
                  n1.position.x > n2.position.x
              }) else {
            fatalErrorIfDebug()
            
            self.init(zIndex: zIndex)
            return
        }

        guard let northNodeSize = northNode.sizeByLocalBounds,
              let southNodeSize = southNode.sizeByLocalBounds,
              let westNodeSize = westNode.sizeByLocalBounds,
              let eastNodeSize = eastNode.sizeByLocalBounds else {
            
            self.init(zIndex: zIndex)
            return
        }

        let nodeIds = CanvasItemIdSet(nodes.map(\.id))

        let north = northNode.position.y
        // print("init: northNode.color: \(northNode.color)")
        // print("init: northNode.size: \(northNode.size)")

        // print("init: southNode.color: \(southNode.color)")
        // print("init: southNode.size: \(southNode.size)")
        let south = southNode.position.y + southNodeSize.height

        // print("init: westNode.color: \(westNode.color)")
        // print("init: westNode.size: \(westNode.size)")
        let west = westNode.position.x

        // print("init: eastNode.color: \(eastNode.color)")
        // print("init: eastNode.size: \(eastNode.size)")
        let east = eastNode.position.x + eastNodeSize.width

        // print("init: north: \(north)")
        // print("init: south: \(south)")
        // print("init: west: \(west)")
        // print("init: east: \(east)")

        let titleHeightAllowance: CGFloat = 100

        let width = (west - east).magnitude
        let height = (north - south).magnitude
        //        let width = (west - east).magnitude * 1/scale
        //        let height = (north - south).magnitude * 1/scale

        // 500.0 //north.position.y - south.position.y

        print("init: width: \(width)")
        print("init: height: \(height)")

        let topPadding: CGFloat = northNodeSize.height/2
        let bottomPadding: CGFloat = southNodeSize.height/2
        //        let topPadding: CGFloat = northNode.size.height
        //        let bottomPadding: CGFloat = southNode.size.height
        //        let topPadding: CGFloat = northNode.size.height // * 2
        //        let bottomPadding: CGFloat = southNode.size.height // * 2

        //        let topPadding: CGFloat = northNode.size.height/2 * 1/scale
        //        let bottomPadding: CGFloat = southNode.size.height/2 * 1/scale

        //        let topPadding: CGFloat = 200
        //        let bottomPadding: CGFloat = 200
        let yPadding = topPadding + bottomPadding
        //        let yPadding = topPadding + bottomPadding + 200

        //        let leftPadding: CGFloat = westNode.size.width/2
        //        let rightPadding: CGFloat = eastNode.size.width/2
        let leftPadding: CGFloat = westNodeSize.width/2
        let rightPadding: CGFloat = eastNodeSize.width/2

        //        let leftPadding: CGFloat = westNode.size.width
        //        let rightPadding: CGFloat = eastNode.size.width

        //        let leftPadding: CGFloat = westNode.size.width // * 2
        //        let rightPadding: CGFloat = eastNode.size.width // * 2

        //        let leftPadding: CGFloat = westNode.size.width/2 * 1/scale
        //        let rightPadding: CGFloat = eastNode.size.width/2 * 1/scale

        //        let leftPadding: CGFloat = 200 // westNode.size.width/2
        //        let rightPadding: CGFloat = 200 // eastNode.size.width/2
        let xPadding = leftPadding + rightPadding

        //        let padding = 100.0

        //        let nodePosition: CGSize = .init(
        //            width: west + width/2 - padding/2,
        //            height: north + height/2 - padding/2)

        let nodePosition: CGPoint = .init(
            x: west + width/2 - xPadding/2,
            y: north + height/2 - yPadding/2)

        print("init: nodePosition: \(nodePosition)")

        // zoomed out: e.g. scale = 0.5, so need to make the box bigger,
        // so need to do 1/scale ... 1/0.5 = *2
        //        let initialWidth = (width.magnitude + xPadding) * scale //1/scale
        //        let initialHeight = (height.magnitude + yPadding + titleHeightAllowance) * scale //1/scale

        //        let initialWidth = (width.magnitude * 1/scale) + xPadding
        //        let initialHeight = ((height.magnitude + titleHeightAllowance) * 1/scale) + yPadding

        //        let initialWidth = (width.magnitude * 1/scale) + xPadding
        //        let initialHeight = (height.magnitude * 1/scale) + titleHeightAllowance + yPadding

        //        let initialWidth = (width.magnitude * 0.75/scale) + xPadding
        //        let initialHeight = (height.magnitude * 0.75/scale) + titleHeightAllowance + yPadding

        //        let initialWidth = width.magnitude + xPadding
        //        let initialHeight = height.magnitude + titleHeightAllowance + yPadding

        let initialWidth = width.magnitude + xPadding
        let initialHeight = height.magnitude + titleHeightAllowance + yPadding

        var initialSize = CGSize(width: initialWidth,
                                 height: initialHeight)

        //        var initialSize = CGSize(width: initialWidth * 1/scale,
        //                                 height: initialHeight * 1/scale)

        // EVEN BIGGER
        //        var initialSize = CGSize(width: initialWidth * 1.5/(scale),
        //                                 height: initialHeight * 1.5/scale)

        // smaller, but still varies with zoom out
        //        var initialSize = CGSize(width: initialWidth * 0.5/(scale),
        //                                 height: initialHeight * 0.5/scale)

        // want larger size, the more we're zoomed out;
        // so ... 1 - 0.5 = 0.5
        //        var initialSize = CGSize(width: initialWidth * (1 - scale),
        //                                 height: initialHeight * (1 - scale))

        // better?: 1 / (1 - 0.5)
        // No... as we zoom in, we get something larger
        // there was somewhere else where we had some appropriate formula
        // ... insert node menu animation logic?
        // ... right, in `animateMenu` ? ... but that was for .offset ?
        //        var initialSize = CGSize(width: initialWidth * 1/(1 - scale),
        //                                 height: initialHeight * 1/(1 - scale))

        let expansionBox = CommentExpansionBox(
            expansionDirection: nil,
            // add 100 to width and height, so that we get 50 padding on each size;
            // plus some extra height to counteract title view's position inside the box.
            //            size: .init(width: width.magnitude + padding,
            //                        height: height.magnitude + padding + titleHeightAllowance),
            size: initialSize,
            startPoint: nodePosition,
            endPoint: nodePosition)

        self.init(color: color,
                  nodes: nodeIds,
                  position: nodePosition,
                  expansionBox: expansionBox,
                  zIndex: zIndex)
    }

}

extension CommentBoxViewModel {

//    static let defaultBox = CommentBoxViewModel(
//        nodes: .init(),
//        //        position: .zero,
//        position: .init(x: 200, y: 200),
//        expansionBox: .defaultExpansionBox)

    //    init(nodes: IdSet = .init(),
    //         position: CGSize,
    //         expansionBox: CommentExpansionBox) {
    //        self.nodes = nodes
    //        self.position = position
    //        self.previousPosition = position
    //        self.expansionBox = expansionBox
    //    }

}

//#Preview {
//    CommentBoxView(box: .defaultBox,
//                   isSelected: false,
//                   atleastOneNodeSelected: false)
//}
