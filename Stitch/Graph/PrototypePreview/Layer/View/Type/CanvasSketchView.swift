//
//  CanvasSketchView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/24.
//

import SwiftUI
import StitchSchemaKit

extension Color {
    static var DEBUG_BORDER_COLOR: Color {
        #if DEBUG
        return .blue
        #elseif DEV_DEBUG
        return .red
        #else
        return .clear
        #endif
    }
}

// TODO: rename to e.g. `PreviewCanvasSketchView` to match `PreviewText`
struct CanvasSketchView: View {

    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isGeneratedAtTopLevel: Bool
    let interactiveLayer: InteractiveLayer

    let lineColor: Color
    let lineWidth: CGFloat
    let position: CGSize
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    let lines: DrawingViewLines

    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {

        let view = DrawingView(id: interactiveLayer.id,
                               lines: lines,
                               selectedColor: lineColor,
                               selectedLineWidth: lineWidth,
                               parentSize: parentSize)
            .opacity(opacity)

        // TODO: gesture handlers specific to Canvas, that draw the line; we should fire a redux event that updates the canvas-sketch layer node view model's computed state
        // TODO: confirm these are okay with various .rotation, .position etc. changes

        return view.modifier(PreviewCommonModifier(
            graph: graph,
            layerViewModel: layerViewModel,
            isGeneratedAtTopLevel: isGeneratedAtTopLevel,
            interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
//            size: size.asCGSize(parentSize),
            size: size,
            scale: scale,
            anchoring: anchoring,
            blurRadius: blurRadius,
            blendMode: blendMode,
            brightness: brightness,
            colorInvert: colorInvert,
            contrast: contrast,
            hueRotation: hueRotation,
            saturation: saturation,
            pivot: .defaultPivot,
            shadowColor: shadowColor,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition
        ))
    }
}

// https://github.com/gahntpo/DrawingApp-Youtube-tutorial/blob/main/DrawingApp/DrawingView.swift
struct DrawingView: View {

    let id: PreviewCoordinate
    let lines: [DrawingViewLine]

    let selectedColor: Color
    let selectedLineWidth: CGFloat

    let parentSize: CGSize

    var body: some View {
        canvas
    }

    @MainActor
    var canvas: some View {
        CanvasDrawingView(lines: lines)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged({ value in
                            dispatch(DrawingViewDragged(
                                        id: id,
                                        value: value,
                                        selectedColor: selectedColor,
                                        selectedLineWidth: selectedLineWidth,
                                        parentSize: parentSize))
                        }).onEnded({ _ in
                            dispatch(DrawingViewDragEnded(id: id,
                                                          parentSize: parentSize))
                        }))
    }
}

// Given existing DrawingLines, draw them on the canvas
struct CanvasDrawingView: View {
    let lines: DrawingViewLines

    var body: some View {

        Canvas { context, _ in
            for line in lines {
                context.stroke(
                    DrawingViewHelpers.createPath(for: line.points),
                    with: .color(line.color),
                    style: StrokeStyle(lineWidth: line.lineWidth,
                                       lineCap: .round,
                                       lineJoin: .round))
            }
        }
    }
}

struct DrawingViewDragEnded: ProjectEnvironmentEvent {

    let id: PreviewCoordinate
    let parentSize: CGSize

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {

        // log("DrawingViewDragEnded called: id: \(id)")

        guard let layerNodeViewModel = graphState.getLayerNode(id: id.layerNodeId.id)?.layerNode,
              let layerViewModelAtIndex = layerNodeViewModel.previewLayerViewModels[safe: id.loopIndex] else {
            log("DrawingViewDragEnded: could not find layer node view model for \(id.layerNodeId) or layer view model for loop-index \(id.loopIndex)")
            return .noChange
        }

        if let last = layerViewModelAtIndex.lines.last?.points,
           last.isEmpty {
            layerViewModelAtIndex.lines.removeLast()
        }

        layerViewModelAtIndex.parentSizeFromDrag = parentSize

        graphState.calculate(id.layerNodeId.id)
        return .noChange
    }
}

// what kind of action will this be?
struct DrawingViewDragged: ProjectEnvironmentEvent {
    let id: PreviewCoordinate
    let value: DragGesture.Value
    let selectedColor: Color
    let selectedLineWidth: CGFloat

    let parentSize: CGSize

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {

        //        log("DrawingViewDragged called: id: \(id)")

        guard let layerNodeViewModel = graphState.getLayerNode(id: id.layerNodeId.id)?.layerNode,
              let layerViewModelAtIndex = layerNodeViewModel.previewLayerViewModels[safe: id.loopIndex] else {
            log("DrawingViewDragged: could not find layer node view model for \(id.layerNodeId) or layer view model for loop-index \(id.loopIndex)")
            return .noChange
        }

        let newPoint = value.location

        if value.translation.width + value.translation.height == 0 {
            // TODO: use selected color and linewidth
            layerViewModelAtIndex.lines.append(DrawingViewLine(
                                                points: [newPoint],
                                                color: selectedColor,
                                                lineWidth: selectedLineWidth))
        } else {
            let index = layerViewModelAtIndex.lines.count - 1
            layerViewModelAtIndex.lines[index].points.append(newPoint)
        }

        layerViewModelAtIndex.parentSizeFromDrag = parentSize

        graphState.calculate(id.layerNodeId.id)
        return .noChange
    }
}

// #Preview {
//    CanvasSketchView()
// }
