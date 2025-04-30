//
//  AdjustmentBarPopoverView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/1/22.
//

import SwiftUI
import StitchSchemaKit

let STEP_SCALE_BUTTON_CORNER_RADIUS: CGFloat = 10

let STEP_SCALE_BUTTON_HEIGHT: CGFloat = 28

let STEP_SCALE_BUTTON_HIGHLIGHTED: Color = Color(.stepScaleButtonHighlighted)

// Size of the entire popover
let ADJUSTMENT_BAR_POPOVER_WIDTH: CGFloat = 292
let ADJUSTMENT_BAR_POPOVER_HEIGHT: CGFloat = 292

let ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE: CGSize = CGSize(width: 24, height: 24)

let ADJUSTMENT_BAR_POPOVER_BACKGROUND_COLOR: Color = Color(.adjustmentBarPopoverBackground)

let ADJUSTMENT_BAR_POPOVER_BUTTON_BACKGROUND_COLOR: Color = Color(.adjustmentBarPopoverButtonBackground)

struct AdjustmentBarPopoverView: View {
    @Bindable var graph: GraphState

    // Value heled in Redux, which won't trigger re-renders
    let stateNumber: Double
    let fieldValueNumberType: FieldValueNumberType
    let fieldCoordinate: FieldCoordinate
    let rowObserver: InputNodeRowObserver
    let isFieldInsideLayerInspector: Bool
    let activeIndex: ActiveIndex
    
    @Binding var isPopoverOpen: Bool

    @State private var currentStepScale: AdjustmentBarStepScale = .normal
    /*
     "Old state"; what we started the bar off with.

     Only updated when step-scale changes.

     Note: if we constantly updated these values, we would be re-rendering the scroll view constantly, which would mess it up.
     We only want to (and must) re-render the scroll view when step-scale changes.
     */
    @State var barNumber: Double = .zero

    @State var centerSelectionDisabled = false

    var body: some View {
        VStack(spacing: 12) {
            autoButtonsRow
            stepScaleButtonsRow
            adjustmentBar
        }
        .padding(16)
        .frame(width: ADJUSTMENT_BAR_POPOVER_WIDTH,
               height: ADJUSTMENT_BAR_POPOVER_HEIGHT)
        .background(ADJUSTMENT_BAR_POPOVER_BACKGROUND_COLOR)
        .cornerRadius(STEP_SCALE_BUTTON_CORNER_RADIUS)

        .onChange(of: currentStepScale) { _, _ in
            //            log("AdjustmentBarPopoverView: onChange: currentStepScale: oldStepScale: \(oldStepScale)")
            //            log("AdjustmentBarPopoverView: onChange: currentStepScale: newStepScale: \(newStepScale)")
            //            log("AdjustmentBarPopoverView: onChange: currentStepScale: barNumber: \(barNumber)")
            //            log("AdjustmentBarPopoverView: onChange: currentStepScale: number: \(number)")

            barNumber = stateNumber
        }
        .onAppear {
            centerSelectionDisabled = false
            barNumber = stateNumber
        }
        .onDisappear {
            self.isPopoverOpen = false
            
            // Encoding was ignored with adjustment bar until this point
            self.graph.encodeProjectInBackground()
        } // .onDisappear
    }

    @ViewBuilder @MainActor
    var autoButton: some View {
        // Layer dimension supports auto button
        if fieldValueNumberType.isLayerDimension {
            Button {
                /*
                 HACK: When popover is de-rendering, our center-selection logic actually fires a couple times.
                 Thus we need to disable center-selection as popover is closing from auto-button press.
                 */
                centerSelectionDisabled = true

                // Hide popover
                self.isPopoverOpen = false

                graph.inputEditedFromUI(
                    fieldValue: .layerDimension(.auto),
                    fieldIndex: fieldCoordinate.fieldIndex,
                    rowId: fieldCoordinate.rowId,
                    activeIndex: activeIndex,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    isCommitting: false)
            } label: {
                Image(systemName: "bolt.badge.a.fill")
                    .resizable()
                    .foregroundColor(STITCH_FONT_WHITE_COLOR)
                    .frame(width: 12,
                           height: 15,
                           alignment: .center)
                    .background {
                        Circle().fill(ADJUSTMENT_BAR_POPOVER_BUTTON_BACKGROUND_COLOR)
                            .frame(width: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.width,
                                   height: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.height)
                    }
                    .frame(width: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.width,
                           height: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.height)
            }
        } else {
            EmptyView()
        }
    }

    var closeButton: some View {
        Image(systemName: "xmark")
            .resizable()
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
            .frame(width: 10,
                   height: 10,
                   alignment: .center)
            .background {
                Circle().fill(ADJUSTMENT_BAR_POPOVER_BUTTON_BACKGROUND_COLOR)
                    .frame(width: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.width,
                           height: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.height)
            }
            .frame(width: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.width,
                   height: ADJUSTMENT_BAR_POPOVER_BUTTON_SIZE.height)
            .onTapGesture {
                self.isPopoverOpen = false
            }
    }

    @MainActor
    var autoButtonsRow: some View {
        HStack {
            autoButton
            Spacer()
            closeButton
        }
        .frame(width: WIDE_ADJUSTMENT_BAR_WIDTH,
               height: 24)
    }

    func stepScaleButton(_ scale: AdjustmentBarStepScale) -> some View {

        StitchTextView(string: scale.display)
            .frame(width: self.stepScaleButtonWidth,
                   height: STEP_SCALE_BUTTON_HEIGHT,
                   alignment: .center)
            .background(self.currentStepScale == scale ? STEP_SCALE_BUTTON_HIGHLIGHTED : .clear)
            .cornerRadius(STEP_SCALE_BUTTON_CORNER_RADIUS)
            .onTapGesture {
                self.currentStepScale = scale
            }
            .animation(.linear, value: self.currentStepScale)
    }

    var stepScaleButtonWidth: CGFloat {
        // text width varies by string length;
        // but alotted space for highlight etc is more;
        // TODO: where are these numbers coming from? 262.0 is row width minus padding?
        (262.0 / 3.0) + 2
    }

    var stepScaleButtonsRow: some View {

        // TODO: Why is this negative spacing required?
        HStack(spacing: -6) {
            Spacer()
            stepScaleButton(.small)
            Spacer()
            stepScaleButton(.normal)
            Spacer()
            stepScaleButton(.large)
            Spacer()
        }
        .frame(width: WIDE_ADJUSTMENT_BAR_WIDTH,
               height: STEP_SCALE_BUTTON_HEIGHT)
        .background(ADJUSTMENT_BAR_POPOVER_BUTTON_BACKGROUND_COLOR)
        .cornerRadius(STEP_SCALE_BUTTON_CORNER_RADIUS)
    }

    var adjustmentBar: some View {
        WideAdjustmentBarView(
            graph: graph,
            middleNumber: barNumber,
            stepSize: currentStepScale,
            fieldValueNumberType: fieldValueNumberType,
            centerSelectionDisabled: centerSelectionDisabled,
            fieldCoordinate: fieldCoordinate,
            rowObserver: rowObserver,
            isFieldInsideLayerInspector: isFieldInsideLayerInspector, 
            activeIndex: activeIndex,
            currentlySelectedNumber: barNumber,
            numberLineMiddle: barNumber)
    }
}

// TODO: bring back
// struct AdjustmentBarPopoverView_Previews: PreviewProvider {
//
//    static var previews: some View {
//
//        let uuid = UUID()
//
//        ZStack {
//            Color.blue.opacity(0.3).zIndex(-1)
//            Text("Love").popover(isPresented: .constant(true)) {
//                AdjustmentBarPopoverView(
//                    number: EditType.fakeSingleEditNumber,
//                    editType: .fakeSingle,
//                    fieldCoordinate: .fakeFieldCoordinate,
//                    currentStepScale: .normal,
//                    uuid: uuid,
//                    barNumber: 0)
//                    // required to change color of arrow
//                    .background(ADJUSTMENT_BAR_POPOVER_BACKGROUND_COLOR)
//            }
//        }
//        .scaleEffect(1.5)
//    }
// }
