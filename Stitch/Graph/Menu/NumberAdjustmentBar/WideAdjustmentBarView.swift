//
//  WideAdjustmentBarView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/28/22.
//

import SwiftUI
import StitchSchemaKit

let WIDE_ADJUSTMENT_BAR_WIDTH: CGFloat = 262

let WIDE_ADJUSTMENT_BAR_HEIGHT: CGFloat = 185

let WIDE_ADJUSTMENT_BAR_CORNER_RADIUS: CGFloat = 8

let WIDE_ADJUSTMENT_BAR_ITEM_HEIGHT: CGFloat = 48

// includes +8 width for 4 pt padding on each side, to push out border
let WIDE_ADJUSTMENT_BAR_ITEM_WIDTH: CGFloat = WIDE_ADJUSTMENT_BAR_WIDTH + 8

let WIDE_ADJUSTMENT_BAR_ITEM_DIVIDER_COLOR: Color = Color(.wideAdjustmentBarItemDivider)

let WIDE_ADJUSTMENT_BAR_GRADIENT_COLOR_ONE: Color = Color(.wideAdjustmentBarGradientColorOne)

let WIDE_ADJUSTMENT_BAR_GRADIENT_COLOR_TWO: Color = Color(.wideAdjustmentBarGradientColorTwo)

struct WideAdjustmentBarView: View {
    let graph: GraphState
    // TODO: when field is "auto", pass in the resource's width/height
    let middleNumber: Double
    //    let editType: EditType

    // changing stepSize should indeed cause us to re-render
    let stepSize: AdjustmentBarStepScale

    // if current value is auto,
    // then disable autoSelect until we actually scroll
    let fieldValueNumberType: FieldValueNumberType

    // true just when tearing down view
    let centerSelectionDisabled: Bool
    let fieldCoordinate: FieldCoordinate
    let rowObserverCoordinate: NodeIOCoordinate
    let isFieldInsideLayerInspector: Bool

    @State var scrollCenter: CGPoint?
    @State var isScrollingFromTap = false // replace with just `manuallyClickedNumber`?
    @State var manuallyClickedNumber: AdjustmentNumber?

    // false in onAppear;
    @State var hasBeenScrolled = false

    // Starts out same as `middleNumber`,
    // but unlike `middleNumber` is updated whenever we
    // tap a number or scroll.
    // Used to create a proper number-line.
    @State var currentlySelectedNumber: Double
    @State var numberLineMiddle: Double

    var body: some View {
        //        logInView("\n WideAdjustmentBarView: body: activeAdjustmentField: \(fieldCoordinate)")
        //        logInView("WideAdjustmentBarView: body: middleNumber: \(middleNumber)")
        //        logInView("WideAdjustmentBarView: body: editType: \(editType)")
        //        logInView("WideAdjustmentBarView: body: stepSize: \(stepSize)")
        //        logInView("WideAdjustmentBarView: body: currentValueIsAuto: \(currentValueIsAuto)")

        ZStack {
            gradientBackground.zIndex(-1)
            scroll
        }
        .frame(width: WIDE_ADJUSTMENT_BAR_WIDTH,
               height: WIDE_ADJUSTMENT_BAR_HEIGHT)
        .cornerRadius(WIDE_ADJUSTMENT_BAR_CORNER_RADIUS)
        .onChange(of: self.middleNumber) { _, newValue in
            self.currentlySelectedNumber = newValue
            self.numberLineMiddle = newValue
        }
    }

    var gradientBackground: some View {
        let gradient = LinearGradient(
            colors: [
                WIDE_ADJUSTMENT_BAR_GRADIENT_COLOR_ONE,
                WIDE_ADJUSTMENT_BAR_GRADIENT_COLOR_TWO
            ],
            startPoint: .top,
            endPoint: .bottom)

        return Group {
            ADJUSTMENT_BAR_POPOVER_BACKGROUND_COLOR.opacity(0.4)
            gradient.zIndex(-2)
        }
    }

    var numberLine: [Double] {
        constructNumberline(self.numberLineMiddle,
                            stepScale: stepSize)
    }

    @MainActor
    var scroll: some View {

        let adjustmentBarNumbers: [AdjustmentNumber] = numberLine.map(AdjustmentNumber.init)

        return ScrollViewReader { (proxy: ScrollViewProxy) in
            // `showsIndicators: false` = hide semi-opaque scroll bar on left;
            // causes problems on Catalyst?
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(adjustmentBarNumbers, id: \.id) { n in

                        let textDisplay = n.number.rounded(toPlaces: NUMBER_LINE_ROUNDED_PLACES).description + (fieldValueNumberType.isPercentage ? "%" : "")

                        StitchTextView(string: textDisplay)

                            // SwiftUI location service
                            .anchorPreference(
                                key: BarPrefKey.self,
                                value: .center, // the center of the 48 tall view, within the frame of the entire view or of the screen
                                transform: {
                                    [
                                        n: BarPrefData(number: n.number,
                                                       center: $0,
                                                       field: fieldCoordinate)
                                    ]
                                })

                            // slightly extended width,
                            // to cut off left/right sides of border
                            .frame(width: WIDE_ADJUSTMENT_BAR_ITEM_WIDTH,
                                   height: WIDE_ADJUSTMENT_BAR_ITEM_HEIGHT)
                            .border(WIDE_ADJUSTMENT_BAR_ITEM_DIVIDER_COLOR, width: 1)

                            // Required for quick `ScrollViewProxy.scrollTo`
                            .id(n.id) // n.id is just the number itself

                            // TODO: use a larger hit box?
                            .onTapGesture {
                                // log("onTapGesture: n.number: \(n.number)")
                                isScrollingFromTap = true

                                // tells view to scroll here
                                manuallyClickedNumber = n

                                self.currentlySelectedNumber = n.number

                                // updates input via redux
                                graph.inputEdited(fieldValue: fieldValueNumberType.createFieldValueForAdjustmentBar(from: n.number),
                                                  fieldIndex: self.fieldCoordinate.fieldIndex,
                                                  coordinate: rowObserverCoordinate,
                                                  isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                                  isCommitting: false)
                            }
                    } // ForEach
                } // LazyVStack

                // for detecting whether we've scrolled
                .background(GeometryReader {
                    Color.clear.preference(
                        key: ViewOffsetKey.self,
                        value: -$0.frame(in: .named("scroll")).origin.y)
                })
                .onPreferenceChange(ViewOffsetKey.self) { newScrollOffset in
                    // print("offset >> \(newScrollOffset)")
                    if newScrollOffset != 0,
                       !isScrollingFromTap {
                        // print("we've scrolled...")
                        hasBeenScrolled = true
                    }

                }
                .onChange(of: self.stepSize) { _, _ in
                    self.numberLineMiddle = self.currentlySelectedNumber
                }

                .onChange(of: self.numberLine) { _, _ in
                    // TODO: should be smoother, no jump; at least when step size changes
                    proxy.scrollTo(numberLineMiddle, anchor: .center)
                }

                // TODO: only called first time view is rendered.
                // Means that ScrollView's scroll position is remembered.
                // Returning `false` from `==` implementation doesn't help.
                .onAppear {
                    //                    log("WideAdjustmentBarView: onAppear")
                    isScrollingFromTap = true
                    hasBeenScrolled = false

                    // Do NOT animate the initial scroll to center;
                    // causes adjustment bar to appear to jump around,
                    // and we autoselect a center number during this jumping (bad).
                    proxy.scrollTo(middleNumber, anchor: .center)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // log("onAppear: finished scrolling")
                        // when `isScrollingFromTap` is set false,
                        // "auto select center" logic is re-enabled.
                        isScrollingFromTap = false
                    }
                } // .onAppear

                // an item's onTap handler sets `manuallyClickedNumber` non-nil
                .onChange(of: manuallyClickedNumber) { (newManuallyClicked: AdjustmentNumber?) in
                    // log("WideAdjustmentBarView: onChange of manuallyClickedNumber: newManuallyClicked: \(newManuallyClicked)")

                    guard let newManuallyClicked = newManuallyClicked else {
                        // log("onChange of manuallyClickedNumber: early exit")
                        return
                    }

                    isScrollingFromTap = true
                    withAnimation {
                        proxy.scrollTo(newManuallyClicked.id, anchor: .center)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        // log("onChange of manuallyClickedNumber: finished scrolling")
                        // when `isScrollingFromTap` is set false,
                        // "auto select center" logic is re-enabled.
                        isScrollingFromTap = false

                        // TODO: can reset this earlier?
                        // reset the manually clicked item
                        manuallyClickedNumber = nil
                    }
                } // .onChange

            } // ScrollView
            .coordinateSpace(name: "scroll")

        } // ScrollViewReader

        // Required for smooth scrolling when `middleNumber` changes
        .animation(.default, value: middleNumber)

        // The center of the entire ScrollView
        .anchorPreference(
            key: ScrollCenterPrefKey.self,
            value: .center,
            transform: {
                [
                    SCROLL_CENTER_KEY: ScrollCenterPrefData(center: $0)
                ]
            })

        // THE CENTER OF THE SCROLL VIEW
        .overlayPreferenceValue(ScrollCenterPrefKey.self) { (preferences: ScrollCenterPrefDict) in
            GeometryReader { geometry in
                if let x: ScrollCenterPrefData = preferences[SCROLL_CENTER_KEY] {
                    readCenter(oldCenter: scrollCenter,
                               currentCenter: geometry[x.center],
                               onChange: { (newCenter: CGPoint) in
                                scrollCenter = newCenter
                               })

                }
            }
        }

        // ACCESSING THE CENTER VALUES FOR EACH NUMBER VIEW (48 points tall) IN THE LIST
        .overlayPreferenceValue(BarPrefKey.self) { (preferences: BarPrefDict) in
            GeometryReader { geometry in
                if let scrollCenter = scrollCenter,

                   // to avoid selecting center upon view start or close,
                   // when bar's value is "auto"
                   canAutoSelectCenter,
                   !centerSelectionDisabled,

                   // to avoid selecting center while scrolling from tap
                   !isScrollingFromTap {

                    autoSelectAdjustmentBarCenter(geometry: geometry,
                                                  preferences: preferences,
                                                  scrollCenter: scrollCenter,
                                                  fieldValueNumberType: fieldValueNumberType)
                }
            } // GeometryReader
        } // .overlayPref
    }

    var canAutoSelectCenter: Bool {
        if fieldValueNumberType == .layerDimension(.auto) && !hasBeenScrolled {
            return false
        }
        return true
    }

    @MainActor
    func autoSelectAdjustmentBarCenter(geometry: GeometryProxy,
                                       preferences: BarPrefDict,
                                       scrollCenter: CGPoint,
                                       fieldValueNumberType: FieldValueNumberType) -> EmptyView {

        let centerLocatedWithinItem = { (pref: BarPrefData) -> Bool in

            let prefCenter: CGPoint = geometry[pref.center]

            // Better?:
            // let adjustment = WIDE_ADJUSTMENT_BAR_ITEM_HEIGHT/2
            let adjustment: CGFloat = 40

            let topBound = prefCenter.y - adjustment
            let bottomBound = prefCenter.y + adjustment

            // newCenter: (200.0, 150.0) -- NEVER changes ?
            let withinTop = scrollCenter.y > topBound
            let withinBottom = scrollCenter.y < bottomBound

            let withinCenter = withinTop && withinBottom

            //        if withinCenter {
            //            log("\n \n centerLocatedWithinItem: pref.id: \(pref.id)")
            //            log("centerLocatedWithinItem: pref.number: \(pref.number)")
            //            log("centerLocatedWithinItem: pref.editType: \(pref.editType)")
            //            log("centerLocatedWithinItem: prefCenter: \(prefCenter)")
            //            log("centerLocatedWithinItem: topBound: \(topBound)")
            //            log("centerLocatedWithinItem: bottomBound: \(bottomBound)")
            //            log("centerLocatedWithinItem: withinTop: \(withinTop)")
            //            log("centerLocatedWithinItem: withinBottom: \(withinBottom)")
            //        }

            return withinCenter
        }

        // #if DEV_DEBUG
        //    log("autoselectCenter: preferences.values numbers: \(preferences.values.map(\.number))")
        // #endif

        let prefsInCenter = preferences
            .values
            .sorted(by: { b, b2 in b.number < b2.number })
            .filter(centerLocatedWithinItem)

        //    log("autoselectCenter: prefsInCenter: \(prefsInCenter)")
        //    log("autoselectCenter: prefsInCenter.count: \(prefsInCenter.count)")

        if let pref = prefsInCenter.last {
            //            #if DEV_DEBUG
            //            log("autoselectCenter: pref was located in center: number: \(pref.number)")
            //            log("autoselectCenter: pref was located in center: field: \(pref.field)")
            //            log("autoselectCenter: pref was located in center: editType: \(pref.editType)")
            //            #endif

            /*
             TODO: what number should the adjustment bar's scroll wheel start on, when the field was previously "auto"?

             (1) media layer: use resource size
             - ideally we just look at the media manager


             (2) non-media layer: parent size, but parent could be e.g. a layer group that's scaled down etc.
             -- tricky: this information currently only implicitly known when creating PreviewWindow contents


             (3) patch node: not sure ? default to 0 ?
             */
            let fieldValue = fieldValueNumberType.createFieldValueForAdjustmentBar(from: pref.number)

            //                log("Auto select center: pref.number: \(pref.number)")
            //                log("Auto select center: self.currentlySelectedNumber: \(self.currentlySelectedNumber)")

            if pref.number != self.currentlySelectedNumber {
                DispatchQueue.main.async {
                    self.currentlySelectedNumber = pref.number

                    // log("Auto select center: pref.number: \(pref.number)")
                    graph.inputEdited(fieldValue: fieldValue,
                                      fieldIndex: pref.field.fieldIndex,
                                      coordinate: rowObserverCoordinate,
                                      isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                                      // We don't persist changes from auto-selectiong the center value during scroll
                                      isCommitting: false)
                }

            }
            //                else {
            //                    log("will NOT dispatch InputEdited")
            //                }
        }
        return EmptyView()
    }

}

struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static let defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

// struct WideAdjustmentBarView_Previews: PreviewProvider {
//    static var previews: some View {
//
//
//        WideAdjustmentBarView(
//            activeAdjustmentField: FieldCoordinate(input: .fakeInputCoordinate, fieldIndex: 0),
//            middleNumber: fakeSingleEditNumber,
//            editType: .fakeSingle,
//            stepSize: .normal,
//            currentValueIsAuto: false)
//    }
// }
