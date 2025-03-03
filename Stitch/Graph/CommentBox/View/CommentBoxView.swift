//
//  CommentBoxView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/6/23.
//

import SwiftUI
import StitchSchemaKit

typealias DragGestureTypeSignature = _EndedGesture<_ChangedGesture<DragGesture>>

struct CommentBoxView: View {

    @Environment(\.appTheme) private var theme
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    @Bindable var document: StitchDocumentViewModel

    @Bindable var box: CommentBoxViewModel
    let isSelected: Bool // = false
    
    @MainActor
    var atleastOneNodeSelected: Bool {
        !graph.selectedNodeIds.isEmpty
    }

    @MainActor
    var isBeingEdited: Bool {
        graphUI.activelyEditedCommentBoxTitle.map {
            $0 == id
        } ?? false
    }

    // updated to be box.title value when view first appears;
    // and afterward redux and local-state bindings are kept in sync
    @State var title: String = ""

    @FocusState private var isFocused: Bool

    // DEBUG
    @State var redPosition: CGSize = .zero
    @State var redPreviousPosition: CGSize = .zero

    @MainActor
    var commentBoxBoundsDict: CommentBoxBoundsDict {
        graphUI.commentBoxBoundsDict
    }

    @MainActor
    var boundsDictEntry: CommentBoxBounds? {
        self.commentBoxBoundsDict.get(id)
    }

    @MainActor
    var borderBoundsDictEntry: CGRect? {
        self.commentBoxBoundsDict.get(id)?.borderBounds
    }

    @MainActor
    var titleBoundsDictEntry: CGRect? {
        self.commentBoxBoundsDict.get(id)?.titleBounds
    }

    static let commentBoxBorderWidth: CGFloat = 16.0

    static var doubleBorderWidth: CGFloat {
        (Self.commentBoxBorderWidth * 2)
    }

    var body: some View {
        ZStack {
            boxView
            titleView
        }
        .overlay(selectionBorder)
        .simultaneousGesture(TapGesture().onEnded({ _ in
            log("simultaneousGesture: TapGesture: onEnded")
            document.commentBoxTapped(box: self.box)
        }))
        .onChange(of: self.boundsDictEntry) { _, newValue in
            log("CommentBoxView: onChange of: self.boundsDictEntry")
            if newValue == nil {
                log("CommentBoxView: onChange of: self.boundsDictEntry: will dispatch UpdateCommentBoxBounds")
                document.updateCommentBoxBounds(
                    box: box,
                    bounds: self.boxBounds)
            }
        }
    }

    var id: CommentBoxId {
        self.box.id
    }

    var debugPseudoNode: some View {
        Rectangle()
            .fill(.red.opacity(0.5))
            .frame(width: 100, height: 75)
            .position(x: redPosition.width,
                      y: redPosition.height)
            .onAppear {
                redPosition = self.box.expansionBox.anchorCorner.toCGSize
                redPreviousPosition = redPosition
            }
    }

    var selectionBorder: some View {
        RoundedRectangle(cornerRadius: .commentBoxCornerRadius + 8)
            .strokeBorder(isSelected ? theme.themeData.highlightedEdgeColor : .clear,
                          lineWidth: 3)
            .frame(width: box.expansionBox.size.width + 6,
                   height: box.expansionBox.size.height + 6)
            .position(box.expansionBox.anchorCorner)
    }

    @MainActor
    var editor: some View {
        CommentBoxTitleEditView(
            id: id,
            isBeingEdited: isBeingEdited,
            edit: $title,
            width: box.expansionBox.size.width - 62,
            height: box.titleHeight - 31)
            .offset(x: -32)
            .onChange(of: self.title) { _, newValue in
                // box.title = newValue
                DispatchQueue.main.async {
                    dispatch(CommentBoxTitleEdited(id: id, title: newValue))
                }
            }
    }

    @ViewBuilder
    @MainActor
    var titleView: some View {
        editor
            .padding([.leading, .trailing], 32)
            .foregroundColor(.white) // Always white color font
            .frame(width: max(0, box.expansionBox.size.width - (Self.doubleBorderWidth - 1)),
                   height: max(0, box.titleHeight - (Self.doubleBorderWidth - 1)),
                   alignment: .topLeading)
            .padding(.bottom)
            .background {
                titleBoundsReader
            } // .background
            .overlay(alignment: .topTrailing) {
                commentTagMenu
            }
            #if targetEnvironment(macCatalyst)
            .contextMenu { commentTagMenuButtons } // right-click to open tag menu
            #endif
            // Same position as box...
            .position(box.expansionBox.anchorCorner)
            // ... but shifted upward, though not so much that we cover the 16-pixel border
            .offset(y: -box.expansionBox.size.height/2 + box.titleHeight/2)

            .simultaneousGesture(
                TapGesture(count: 2).onEnded({ _ in
                    if isBeingEdited {
                        graphUI.commentBoxTitleEditEnded()
                    } else {
                        graphUI.commentBoxTitleEditStarted(id: id)
                    }

                })
            )
            .gesture(positionDrag)
            .onAppear(perform: {
                title = box.title
            })
    }

    @MainActor
    var commentTagMenuButtons: some View {
        CommentBoxTagMenuButtonsView(
            graph: graph,
            graphUI: graphUI,
            box: box,
            atleastOneNodeSelected: atleastOneNodeSelected)
    }

    @MainActor
    var commentTagMenu: some View {
        Menu {
            commentTagMenuButtons
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.white)
        }
        .foregroundColor(.white)

        #if targetEnvironment(macCatalyst)
        .buttonStyle(.plain)
        .scaleEffect(1.4)
        .frame(width: 24, height: 24)
        #else
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .frame(width: 24, height: 24)
        #endif
    }

    @MainActor
    var borderBoundsReader: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    // log("CommentBoxView: boxBoundsReader: onAppear")

                    self.boxBounds.borderBounds = geometry
                        .frame(in: .named(GraphBaseView.coordinateNamespace))

                    // log("CommentBoxView: boxBoundsReader: onAppear: self.boxBounds.borderBounds is now: \(self.boxBounds.borderBounds)")

                    // if this box has no entry in the comment-box-bounds dict,
                    // then update the state with the box's current bounds:
                    //                    if !self.commentBoxBoundsDict.hasKey(id) {
                    // log("CommentBoxView: boxBoundsReader: onAppear: will dispatch UpdateCommentBoxBounds")
                    document.updateCommentBoxBounds(
                        box: box,
                        bounds: self.boxBounds)
                }
                .onChange(of: geometry.frame(in: .named(GraphBaseView.coordinateNamespace))) { _, newSelectionBounds in
                    // log("CommentBoxView: boxBoundsReader: onChange")
                    //                    self.boxBounds = newSelectionBounds
                    self.boxBounds.borderBounds = newSelectionBounds
                }
        }
    }

    @MainActor
    var titleBoundsReader: some View {
        GeometryReader { geometry in
            self.box.color
                .onAppear {
                    // log("CommentBoxView: titleBoundsReader: onAppear")
                    //                    self.boxBounds = geometry
                    //                        .frame(in: .named(GraphBaseView.coordinateNamespace))

                    self.boxBounds.titleBounds = geometry
                        .frame(in: .named(GraphBaseView.coordinateNamespace))

                    // log("CommentBoxView: titleBoundsReader: onAppear: self.boxBounds.titleBounds is now: \(self.boxBounds.titleBounds)")

                    // if this box has no entry in the comment-box-bounds dict,
                    // then update the state with the box's current bounds:
                    //                    if !self.commentBoxBoundsDict.hasKey(id) {
                    // log("CommentBoxView: titleBoundsReader: onAppear: will dispatch UpdateCommentBoxBounds")
                    document.updateCommentBoxBounds(
                        box: box,
                        bounds: self.boxBounds)
                }
                .onChange(of: geometry.frame(in: .named(GraphBaseView.coordinateNamespace))) { _, newSelectionBounds in
                    // log("CommentBoxView: titleBoundsReader: onChange")
                    //                    self.boxBounds = newSelectionBounds
                    self.boxBounds.titleBounds = newSelectionBounds
                }
        }
    }

    @ViewBuilder
    @MainActor
    var boxView: some View {

        RoundedRectangle(cornerRadius: .commentBoxCornerRadius)
            .strokeBorder(self.box.color,
                          lineWidth: Self.commentBoxBorderWidth)

            // TODO: is this as performant as it could be?
            .background {
                borderBoundsReader
            } // .background

            .frame(width: box.expansionBox.size.width,
                   height: box.expansionBox.size.height)
            .position(box.expansionBox.anchorCorner)
            .gesture(expansionDrag)
    }

    //    @State var boxBounds: CGRect = .zero
    @State var boxBounds: CommentBoxBounds = .init()

    // COMMENT BOX DRAGGED (Location changed)
    @MainActor
    var positionDrag: DragGestureTypeSignature {
        //        DragGesture()
        // use .global, to match nodes' DragGestures,
        // so we can use same zoom-application rules for both nodes and comment box
        DragGesture(coordinateSpace: .global)
            .onChanged { value in

                redPosition.width = redPreviousPosition.width + value.translation.width
                redPosition.height = redPreviousPosition.height + value.translation.height

                document.commentBoxPositionDragged(id: id, value: value)
            }
            .onEnded { _ in
                redPreviousPosition = redPosition
                document.commentBoxPositionDragEnded()
            }
    }

    // COMMENT BOX EXPANDED
    @MainActor
    var expansionDrag: DragGestureTypeSignature {
        //        DragGesture()
        // use .global, to match nodes' DragGestures,
        // so we can use same zoom-application rules for both nodes and comment box
        //        DragGesture(coordinateSpace: .global)

        // Expansion drag needs to use same coordinate space as node views models,
        // since
        DragGesture(coordinateSpace: .named(GraphBaseView.coordinateNamespace))
            .onChanged { newValue in
                // print("expansionDrag: dragged")
                document.commentBoxExpansionDragged(box: box, value: newValue)
            }
            .onEnded({ value in
                // print("expansionDrag: drag ended")
                document.commentBoxExpansionDragEnded(
                    box: box,
                    value: value,
                    newestBoxBounds: self.boxBounds)
            })
    }
}
