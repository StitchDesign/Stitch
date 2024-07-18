//
//  ReadOnlyEntry.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

// TODO: OutputView's fields should support clicking and highlighting? Can be done via a TextField that receives a .constant(stringValue) binding.

// TODO: remove this in favor of StitchTextView, or is it worthwhile to have a separate view for later potential changes to 'read only' value displays?
struct ReadOnlyValueEntry: View {
    let value: String

    // left alignment for all inputs and multifield outputs
    // right alignment for single-field outputs
    let alignment: Alignment // = .trailing
    var fontColor: Color = STITCH_FONT_GRAY_COLOR

    var body: some View {
        StitchTextView(string: value,
                       fontColor: fontColor)
            // Monospacing prevents jittery node widths if values change on graphstep
            .monospacedDigit()
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   alignment: alignment)
    }
}

// struct ReadOnlyEntry_Previews: PreviewProvider {
//    static var previews: some View {
//        ReadOnlyEntry()
//    }
// }

struct PaddingReadOnlyView: View {
    
    @Bindable var rowObserver: InputNodeRowObserver
    @Bindable var rowData: InputNodeRowObserver.RowViewModelType
    let labelView: LabelDisplayView
    
    @State var hoveredFieldIndex: Int? = nil
    
    var nodeId: NodeId {
        self.rowObserver.id.nodeId
    }
    
    var body: some View {
        Group {
            labelView
            
            Spacer()
            
            // Want to just display the values; so need a new kind of `display only` view
            ForEach(rowData.fieldValueTypes) { fieldGroupViewModel in
                
                ForEach(fieldGroupViewModel.fieldObservers)  { (fieldViewModel: InputFieldViewModel) in
                    
                    let fieldIndex = fieldViewModel.fieldIndex
                    
                    StitchTextView(string: fieldViewModel.fieldValue.stringValue,
                                   fontColor: STITCH_FONT_GRAY_COLOR)
                    
                    // Monospacing prevents jittery node widths if values change on graphstep
                    .monospacedDigit()
                    // TODO: what is best width? Needs to be large enough for 3-digit values?
                    .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH - 12)
                    .background {
                        if self.hoveredFieldIndex == fieldViewModel.fieldIndex {
                            INPUT_FIELD_BACKGROUND.cornerRadius(4)
                        }
                    }
                    .onHover { hovering in
                        withAnimation {
                            if hovering {
                                self.hoveredFieldIndex = fieldIndex
                            } else if self.hoveredFieldIndex == fieldIndex {
                                self.hoveredFieldIndex = nil
                            }
                        }
                    }
                } // ForEach
                
            } // Group
            
            // Tap on the read-only fields to open padding flyout
            .onTapGesture {
                dispatch(FlyoutToggled(flyoutInput: .padding,
                                       flyoutNodeId: nodeId))
            }
        }
    }
}
