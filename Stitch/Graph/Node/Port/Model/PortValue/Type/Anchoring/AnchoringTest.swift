//
//  AnchoringTest.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// LEGACY DEVELOPMENT CODE

/* ---------------------------------------
 VIEWS
 ------------------------------------------ */

struct LayerTest: View {

    var id: String
    var size: CGSize
    let color: Color
    let parentSize: CGSize
    let parentPosition: CGSize
    let anchor: Anchoring

    let scaleFactor: CGFloat = 1.0

    let hasScrollInteraction: Bool
    let hasDragInteraction: Bool = false

    // for local testing will need Stateful position and prevPosition
    @State private var localPosition: CGSize
    @State private var localPreviousPosition: CGSize

    // Don't need to be stored in redux?
    @State private var canScroll: Bool = false
    @State private var translationModification: CGFloat = 0

    init(id: String,
         size: CGSize,
         position: CGSize,
         color: Color,
         parentSize: CGSize,
         parentPosition: CGSize,
         anchor: Anchoring,
         hasScrollInteraction: Bool) {

        self.id = id
        self.size = size
        self._localPosition = State.init(initialValue: position)
        self._localPreviousPosition = State.init(initialValue: position)
        self.color = color
        self.parentSize = parentSize
        self.parentPosition = parentPosition
        self.anchor = anchor
        self.hasScrollInteraction = hasScrollInteraction
    }

    var body: some View {

        let pos = adjustPosition(
            size: size,
            // use local stateful position
            position: localPosition,
            anchor: anchor,
            parentSize: parentSize)

        ZStack {
            id != "List" ? Text(id) : nil
            color.opacity(0.3)

            id != "List"
                ? nil
                :
                VStack {
                    Text("Level 1 \(id)")
                    Spacer()
                    Text("Level 2 \(id)")
                    Spacer()
                    Text("Level 3 \(id)")
                    Spacer()
                    Text("Level 4 \(id)")
                    Spacer()
                    Text("Level 5 \(id)")
                }
            //
            //            color
        }
        .frame(size)
        .border(Color.purple)
        .position(CGPoint(x: pos.width, y: pos.height))
        .gesture(DragGesture()
                    .onChanged {
                        log("LayerTest onChanged")
                        //                        log("LayerTest onChanged: self.localPosition: \(self.localPosition)")
                        //                        log("LayerTest onChanged: localPreviousPosition: \(self.localPreviousPosition)")

                        if !canScroll
                            && hasScrollInteraction
                            && shouldScroll(parentSize: parentSize,
                                            childSize: size,
                                            dragGesture: $0) {

                            canScroll = true

                            let isNeg: Bool = $0.translation.height < 0

                            // if moved 8 in positive direction, want to subtract out the 8
                            translationModification = isNeg
                                ? minimumScrollDistance
                                : -minimumScrollDistance
                        }

                        if canScroll {
                            self.localPosition = onScroll(
                                translationSize: $0.translation,
                                previousPosition: localPreviousPosition.toCGPoint,
                                position: localPosition.toCGPoint,
                                size: size,
                                parentSize: parentSize).toCGSize
                        }
                    }
                    .onEnded { _ in
                        log("LayerTest onEnded")
                        //                        log("LayerTest onEnded: self.localPosition: \(self.localPosition)")
                        self.localPreviousPosition = self.localPosition
                        canScroll = false
                    }
        ) // .gesture
    }
}

struct GroupingTest<Content: View>: View {

    let content: Content
    var size: CGSize
    let color: Color
    let parentSize: CGSize
    let parentPosition: CGSize
    let anchor: Anchoring

    let hasScrollInteraction: Bool
    let hasDragInteraction: Bool = false

    // for local testing will need Stateful position and prevPosition
    @State private var localPosition: CGSize
    @State private var localPreviousPosition: CGSize

    init(content: Content,
         size: CGSize,
         position: CGSize,
         color: Color,
         parentSize: CGSize,
         parentPosition: CGSize,
         anchor: Anchoring,
         hasScrollInteraction: Bool) {

        self.content = content
        self.size = size
        self.color = color
        self.parentSize = parentSize
        self.parentPosition = parentPosition
        self.anchor = anchor
        self.hasScrollInteraction = hasScrollInteraction
        self._localPosition = State.init(initialValue: position)
        self._localPreviousPosition = State.init(initialValue: position)
    }

    var body: some View {

        let pos = adjustPosition(
            size: size,
            // use local stateful position
            position: localPosition,
            anchor: anchor,
            parentSize: parentSize)

        let _ = logInView("Group body: localPosition: \(localPosition)")
        let _ = logInView("Group body: pos: \(pos)")

        ZStack {
            Text("GROUP CENTER").foregroundColor(.red)
            content
            color.opacity(0.2)
        }
        .frame(size)
        .border(Color.blue)
        .clipped() // should be controlled by a boolean like Origami
        .position(CGPoint(x: pos.width, y: pos.height))
        .gesture(DragGesture()
                    .onChanged { _ in
                        let _ = logInView("GroupingTest onChanged")

                        //                        self.localPosition = onDragChanged(
                        //                            value: $0,
                        //                            previousPosition: localPreviousPosition,
                        //                            position: localPosition, // added
                        //                            size: size,
                        //                            parentSize: parentSize,
                        //                            parentPosition: parentPosition,
                        //                            hasScrollInteraction: hasScrollInteraction)
                    }
                    .onEnded { _ in
                        self.localPreviousPosition = self.localPosition
                    }
        ) // .gesture
    }
}

// the entire preview window
struct PreviewWindow<Content: View>: View {

    let content: Content
    let size: CGSize // ie iPhone vs iPand

    var body: some View {
        ZStack {
            content
            //            Color.gray.opacity(0.2)
            Text("PREVIEW CENTER").foregroundColor(.red)
        }
        .frame(size)
        .border(Color.red)
    }
}

/* ---------------------------------------
 PREVIEW
 ------------------------------------------ */

let navBarSize = CGSize(
    width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
    height: 64)

let tabBarSize = CGSize(
    width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
    height: 49)

let tabBarPosition = CGSize(
    width: .zero,
    height: navBarSize.height + groupSize.height)

// eg "the long scrollable instagram image"
// let listSize = CGSize(
//    width: iPhone11FullWidth,
//    height: iPhone11FullHeight * 1.2
//    height: 1890
// )

let listSize = CGSize(
    width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
    //    height: iPhone11FullHeight * 1.2
    height: 1890
)

let listSize2 = CGSize(
    width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width / 2,
    height: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.height * 1.2
    //    height: 1890
)

// size of group
let groupSize = CGSize(
    width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
    //    height: previewWindowHeightFullSize + 200)
    height: 699)

let groupPosition = CGSize(
    width: .zero,
    height: navBarSize.height)

// size of full preview window
let prototypeSize = CGSize(
    width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
    height: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.height)

struct AnchoringTestView: View {

    var body: some View {

        //        let navBar = LayerTest(
        //            id: "Nav",
        //            size: navBarSize,
        //            position: .zero, // start out at tab
        //            color: .yellow.opacity(0.3),
        //            parentSize: groupSize,
        //            parentPosition: .zero, // INACCURATE, IGNORE
        //            anchor: .topLeft,
        //            anchor: .topLeft,
        //            hasScrollInteraction: false)
        //
        //        let tabBar = LayerTest(
        //            id: "Tab",
        //            size: tabBarSize,
        //            // at bottom of both navbar and List
        //            position: tabBarPosition,
        //            color: .pink.opacity(0.3),
        //            parentSize: groupSize,
        //            parentPosition: .zero, // INACCURATE, IGNORE
        //            anchor: .topLeft,
        //            hasScrollInteraction: false)
        //
        //        let list = LayerTest(
        //            id: "List",
        //            size: listSize,
        //            position: .zero,
        //            color: .green.opacity(0.3),
        //            parentSize: groupSize,
        //            parentPosition: groupPosition,
        //            anchor: .topLeft,
        //            hasScrollInteraction: true)
        //
        //        let list2 = LayerTest(
        //            id: "List2",
        //            size: listSize2,
        //            position: CGSize(width: listSize.width, height: 0),
        //            color: .blue.opacity(0.3),
        //            parentSize: groupSize,
        //            parentPosition: groupPosition,
        //            anchor: .topLeft,
        //            anchor: .topRight,
        //            hasScrollInteraction: true)
        //
        //
        //        // let groupContent = ZStack {
        //        //     list
        //        //     list2
        //        // }
        //
        //
        //        let group = GroupingTest(
        //            content: list,
        //            content: groupContent,
        //            size: groupSize,
        //            position: CGSize(width: 50, height: 100),
        //            position: groupPosition,
        //            color: .blue,
        //            parentSize: prototypeSize,
        //            parentPosition: .zero, // INACCURATE, IGNORE
        //            anchor: .topLeft,
        //            hasScrollInteraction: false)

        //        let previewWindowContent = ZStack {
        //            navBar
        //            tabBar
        //            group
        //        }

        //        return PreviewWindow(
        //            content: previewWindowContent,
        //            size: prototypeSize)

        let parentSize = CGSize(width: 400, height: 400)

        let box = LayerTest(
            id: "box",
            size: CGSize(width: 100, height: 100),
            position: .zero,
            color: .blue,
            parentSize: parentSize,
            parentPosition: .zero,
            anchor: .bottomLeft,
            hasScrollInteraction: false)

        let simpleGroup = GroupingTest(
            content: box,
            size: parentSize,
            position: .zero,
            color: .green,
            parentSize: CGSize(width: 700, height: 700),
            parentPosition: .zero,
            anchor: .topLeft,
            hasScrollInteraction: false)

        return simpleGroup

    }
}

struct Anchoring_Previews: PreviewProvider {
    static var previews: some View {
        AnchoringTestView()
    }
}
