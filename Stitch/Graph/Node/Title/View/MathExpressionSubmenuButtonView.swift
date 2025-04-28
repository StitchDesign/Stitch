//
//  MathExpressionPopoverView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/21/24.
//

import SwiftUI
import StitchSchemaKit
import OrderedCollections


struct MathExpressionFormulaEdited: StitchDocumentEvent {
    let id: NodeId // pass the reference instead?
    let newExpression: String
    
    func handle(state: StitchDocumentViewModel) {
        
        let graph = state.visibleGraph
        
        // Can fail when e.g. used in node view; that's okay.
        guard let node = graph.getNode(id) else {
            log("MathExpressionFormulaEdited: no math expression defined for node \(id)")
            return
        }
        
        assertInDebug(node.kind.getPatch == .mathExpression)
        
        node.patchNode?.updateMathExpressionNodeInputs(newExpression: newExpression, 
                                                       node: node,
                                                       activeIndex: state.activeIndex)
        node.scheduleForNextGraphStep()
    }
}

struct MathExpressionFocused: StitchDocumentEvent {
    let id: NodeId
    
    func handle(state: StitchDocumentViewModel) {
        state.reduxFocusedField = .mathExpression(id)
    }
}

struct MathExpressionDefocused: StitchDocumentEvent {
    let id: NodeId
    
    func handle(state: StitchDocumentViewModel) {
        if case state.reduxFocusedField = .mathExpression(id) {
            state.reduxFocusedField = nil
            state.encodeProjectInBackground()
        }
    }
}

// ViewModifier only applied to NodeTitleView if the title is for a 
struct MathExpressionPopoverViewModifier: ViewModifier {
    @State private var show = false
    @State private var expr = "" // Alternatively?: pass down a @Bindable mathExpression
    
    let id: NodeId
    let document: StitchDocumentViewModel
    let shouldDisplay: Bool
    let mathExpression: String
    
    // more like?: "is popover open"
    var isFocused: Bool {
        document.reduxFocusedField == .mathExpression(id)
    }
    
    func body(content: Content) -> some View {
        guard shouldDisplay else {
            return content.eraseToAnyView()
        }
        
        return content
            .popover(isPresented: self.$show) {
                TextField("", text: self.$expr) {
                    self.show = false // submit closes the popover
                    dispatch(MathExpressionDefocused(id: id))
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
            }
            .onAppear {
                self.expr = mathExpression
            }
            .onDisappear {
                log("onDisappear")
            }
        
        // Allow other view elsewhere in hierarchy to open (or close) this popover
            .onChange(of: self.isFocused, { oldValue, newValue in
                self.show = newValue
            })
        
        // Listen to changes that come from this view itself (e.g. popover closes)
            .onChange(of: self.show, { oldValue, newValue in
                if self.show {
                    dispatch(MathExpressionFocused(id: id))
                } else {
                    dispatch(MathExpressionDefocused(id: id))
                }
            })
        
        // Update graph as we type
            .onChange(of: self.expr) { oldValue, newValue in
                dispatch(MathExpressionFormulaEdited(id: id, newExpression: self.expr))
            }
            .eraseToAnyView()
    }
}

struct MathExpressionSubmenuButtonView: View {
    
    let id: NodeId
    
    var body: some View {
        Button(action: {
            // only ever opens the popover
            dispatch(MathExpressionFocused  (id: id))
        }, label: {
            Text("Edit formula")
        })
    }
}


//
//#Preview {
//    MathExpressionSubmenuButtonView(id: .fakeId,
//                                     mathExpression: "a + b + 1",
//                                     show: true)
//}
