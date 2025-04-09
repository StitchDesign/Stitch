//
//  NodeTextField.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/22.
//

import SwiftUI
import StitchSchemaKit

struct NodeTitleTextField: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    let label: String
    let isCanvasItemSelected: Bool
    var font: Font = STITCH_FONT

    var body: some View {
        StitchTitleTextField(document: document,
                             graph: graph,
                             node: node,
                             canvasItem: canvasItem,
                             titleEditType: .canvas(canvasItem.id),
                             label: label,
                             isCanvasItemSelected: isCanvasItemSelected,
                             font: font)
    }
}
    /// A wrapper view for `TextField` which renders a read-only view when the input isn't in focus. This fixes a performance
    /// issue with `TextField` which becomes exacerbated by many rendered `TextField`'s in a view.
struct StitchTitleTextField: View {
    @State private var isTitleFocused: Bool = false
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasItem: CanvasItemViewModel
    let titleEditType: StitchTitleEdit
    let label: String
    let isCanvasItemSelected: Bool
    var font: Font = STITCH_FONT
    
    @MainActor
    var isFocused: Bool {
        (document.reduxFocusedField?.getNodeTitleEdit == titleEditType)
        // && isCanvasItemSelected
    }

    @State var editWidth: CGFloat? = nil
    
    var body: some View {
        Group {
            if isFocused {
                StitchTextEditingField(
                    currentEdit: label, // starts out as `label`
                    fieldType: .nodeTitle(titleEditType),
                    shouldFocus: false,
                    isForNodeTitle: true,
                    font: font,
                    fontColor: Color(.nodeTitleFont)) { newEdit, isCommitting in
                        node.nodeTitleEdited(titleEditType: titleEditType,
                                             edit: newEdit,
                                             isCommitting: isCommitting,
                                             graph: graph)
                    }
                    // .border(.yellow)
                    .frame(height: NODE_TITLE_HEIGHT,
                           alignment: .leading)
                    .frame(maxWidth: self.editWidth,
                           alignment: .leading)
                    // .border(.orange)
                
#if targetEnvironment(macCatalyst)
                // NOTE: arises when applying StitchFont to SwiftUI Text and TextField views
                    .offset(y: -0.5)  // Matches y axis for read-only string--only needed for Catalyst
#endif
                    // .border(.green)
                    .onAppear {
                        // log("StitchTitleTextField: onAppear: editWidth: \(editWidth)")
                        
//                        let labelWidth = label.widthOfString(usingFont: STITCH_UIFONT)
//                        log("StitchTitleTextField: onAppear: labelWidth: \(labelWidth)")
//                        
                        let canvasItemWidth = canvasItem.sizeByLocalBounds?.width
//                        log("StitchTitleTextField: onAppear: canvasItemWidth: \(canvasItemWidth)")

                        self.editWidth = canvasItemWidth
                    }
                    .onDisappear {
                        // log("StitchTitleTextField: onDisappear: editWidth: \(editWidth)")
                        self.editWidth = nil
                    }
                
            } else {
                StitchTextView(string: readOnlyLabel, font: font)
                    .frame(height: NODE_TITLE_HEIGHT, alignment: .leading)
                // Manually focus this field when user taps.
                // Better as global redux-state than local view-state: only one field in entire app can be focused at a time.
                    .gesture(
                        TapGesture(count: 2).onEnded({ _ in
                            log("NodeTitleTextField double-tapped")
                            document.reduxFieldFocused(focusedField: .nodeTitle(titleEditType))
                        })
                    )
            }
        }
        .frame(minWidth: 20)
    }
    
    var readOnlyLabel: String {
#if DEV_DEBUG
        return label + " " + node.id.debugFriendlyId
#else
        // Show debug-friendly id during debug mode, so user see which nodes are referred to
        if document.llmRecording.mode == .augmentation,
           document.llmRecording.modal == .editBeforeSubmit {
            return label + " " + node.id.debugFriendlyId
        } else {
            return label
        }
        
#endif
    }
}

//#if DEV_DEBUG || DEBUG
// NOTE: Useful in some debug cases
extension String {
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
    
}
//#endif
