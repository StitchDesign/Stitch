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

struct AnchorPopoverView: View {

    let input: InputCoordinate
    let selection: Anchoring

    @State private var isOpen = false

    var body: some View {
        AnchoringGridIconView(anchor: selection)
            .scaleEffect(0.18) // seems best?
            .onTapGesture {
                self.isOpen.toggle()
            }
            .popover(isPresented: $isOpen) {
                popover
                    .padding(ANCHOR_POPOVER_PADDING)
            }
    }

    @MainActor
    func dotButton(_ option: Anchoring) -> some View {
        Button {
            // log("AnchorPopoverView: selected \(option.rawValue)")

            dispatch(PickerOptionSelected(
                        input: input,
                        choice: .anchoring(option),
                        isPersistence: true))

        } label: {
            Image(systemName: option == selection ? ANCHOR_SELECTION_OPTION_ICON : ANCHOR_OPTION_ICON)
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
