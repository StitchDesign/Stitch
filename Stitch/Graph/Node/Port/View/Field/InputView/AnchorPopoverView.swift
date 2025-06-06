//
//  AnchorPopoverView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/23.
//

import SwiftUI
import StitchSchemaKit

let ANCHOR_OPTION_ICON = "circle"
let ANCHOR_SELECTION_OPTION_ICON = "circle.fill"

#if targetEnvironment(macCatalyst)
let ANCHOR_OPTION_SPACING: CGFloat = 12
#else
// More spacing on iPad, for fingers
let ANCHOR_OPTION_SPACING: CGFloat = 18
#endif

let ANCHOR_POPOVER_PADDING = ANCHOR_OPTION_SPACING

struct AnchorPopoverView<RowObserver: NodeRowObserver>: View {
    
    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme
    
    let rowObserver: RowObserver
    let graph: GraphState
    let document: StitchDocumentViewModel
    let selection: Anchoring
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    let hasHeterogenousValues: Bool

    @State private var isOpen = false
    
    var body: some View {
        AnchoringGridIconView(
            anchor: self.hasHeterogenousValues ? nil : selection,
            isSelectedInspectorRow: isSelectedInspectorRow)
            .onTapGesture {
                self.isOpen.toggle()
            }
            .popover(isPresented: $isOpen) {
                popover
                    .padding(ANCHOR_POPOVER_PADDING)
            }
        // Important: place *after* .popover, so that popover's arrow is not so far away from the grid-icon-view
            .scaleEffect(0.18)
    }

    @MainActor
    func dotButton(_ option: Anchoring) -> some View {
        Button {
            // log("AnchorPopoverView: selected \(option.rawValue)")

            if let rowObserver = rowObserver as? InputNodeRowObserver {
                graph.pickerOptionSelected(
                    rowObserver: rowObserver,
                    choice: .anchoring(option),
                    activeIndex: document.activeIndex,
                    isFieldInsideLayerInspector: isFieldInsideLayerInspector,
                    isPersistence: true)                
            }

        } label: {
            Image(systemName: (!self.hasHeterogenousValues && option == selection) ? ANCHOR_SELECTION_OPTION_ICON : ANCHOR_OPTION_ICON)
                .foregroundColor(isSelectedInspectorRow ? theme.fontColor : .primary)
        }
        #if targetEnvironment(macCatalyst)
        .buttonStyle(.borderless)
        #endif
    }

    @MainActor
    var popover: some View {

        VStack(spacing: ANCHOR_OPTION_SPACING) {

            HStack(spacing: ANCHOR_OPTION_SPACING) {
                dotButton(Anchoring.topLeft)
                dotButton(Anchoring.topCenter)
                dotButton(Anchoring.topRight)
            }

            HStack(spacing: ANCHOR_OPTION_SPACING) {
                dotButton(Anchoring.centerLeft)
                dotButton(Anchoring.centerCenter)
                dotButton(Anchoring.centerRight)
            }

            HStack(spacing: ANCHOR_OPTION_SPACING) {
                dotButton(Anchoring.bottomLeft)
                dotButton(Anchoring.bottomCenter)
                dotButton(Anchoring.bottomRight)
            }
        }
    }
}

//struct AnchorPopoverView_Previews: PreviewProvider {
//    static var previews: some View {
//
//        AnchorPopoverView(input: .fakeInputCoordinate,
//                          selection: .centerRight)
//            .scaleEffect(2)
//    }
//}
