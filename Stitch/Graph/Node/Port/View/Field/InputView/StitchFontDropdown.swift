//
//  StitchFontDropdown.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/22/24.
//

import StitchSchemaKit
import SwiftUI

struct StitchFontDropdown: View {

    let rowObserver: InputNodeRowObserver
    let graph: GraphState
    let stitchFont: StitchFont
    let isFieldInsideLayerInspector: Bool
    let isSelectedInspectorRow: Bool
    let hasHeterogenousValues: Bool
    let activeIndex: ActiveIndex
    
    @MainActor
    var finalChoiceDisplay: String {
        self.hasHeterogenousValues ? .HETEROGENOUS_VALUES : self.stitchFont.display
    }
    
    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme
    
    var body: some View {
        Menu {
            subMenu(fontChoice: .sf,
                    fontWeights: StitchFontWeight.allCases.filter(\.isForSF))

            subMenu(fontChoice: .sfMono,
                    fontWeights: StitchFontWeight.allCases.filter(\.isForSFMono))

            subMenu(fontChoice: .sfRounded,
                    fontWeights: StitchFontWeight.allCases.filter(\.isForSFRounded))

            subMenu(fontChoice: .newYorkSerif,
                    fontWeights: StitchFontWeight.allCases.filter(\.isForNewYorkSerif))
        } label: {
            Button { } label: {
                StitchTextView(string: finalChoiceDisplay,
                               fontColor: isSelectedInspectorRow ? theme.fontColor : STITCH_FONT_GRAY_COLOR)
            }
        }
        .menuIndicator(.hidden) // hide caret indicator
        .menuStyle(.button)
        .buttonStyle(.plain)
        .foregroundColor(STITCH_TITLE_FONT_COLOR) // avoids Catalyst accent color
//        #if targetEnvironment(macCatalyst)
//        .pickerStyle(.inline) // avoids unnecessary middle label
//        #endif
    }

    @MainActor
    func subMenu(fontChoice: StitchFontChoice,
                 fontWeights: [StitchFontWeight]) -> some View {

        StitchFontSelectionMenu(fontChoice: fontChoice,
                                fontWeights: fontWeights,
                                currentFontWeight: self.stitchFont.fontWeight) {

            let newStitchFont = StitchFont(fontChoice: fontChoice,
                                           fontWeight: $0)

            graph.pickerOptionSelected(rowObserver: rowObserver,
                                       choice: PortValue.textFont(newStitchFont),
                                       activeIndex: activeIndex,
                                       isFieldInsideLayerInspector: isFieldInsideLayerInspector)
        }
    }
}

struct StitchFontSelectionMenu: View {

    var fontChoice: StitchFontChoice
    var fontWeights: [StitchFontWeight]
    var currentFontWeight: StitchFontWeight
    var callback: (StitchFontWeight) -> Void

    var body: some View {
        // TODO: Better for perf to just use an onChange handler? Profile this?
        let select = Binding<StitchFontWeight>.init {
            currentFontWeight
        } set: { newFontWeight in
            callback(newFontWeight)
        }

        return Picker(fontChoice.rawValue,
                      //                      selection: self.$stitchFont.fontWeight) {
                      selection: select) {

            ForEach(fontWeights, id: \.self) { fontWeight in
                // Button's callback, Text's onTap, etc. are ignored by SwiftUI Picker;
                // we can either use a binding (here) or an `onChange(of: self.stitchFont)` to do our desire `onSet`
                Text(fontWeight.display)
            }
        }
        .pickerStyle(.menu)
    }
}

//#Preview {
//    StitchFontDropdown(input: .fakeInputCoordinate,
//                       stitchFont: .init(.newYorkSerif, .NewYorkSerif_bold))
//}
