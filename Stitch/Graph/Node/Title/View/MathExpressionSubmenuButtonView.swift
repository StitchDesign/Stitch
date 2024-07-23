//
//  MathExpressionPopoverView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/21/24.
//

import SwiftUI
import StitchSchemaKit
import OrderedCollections

func fatalErrorIfDebug(_ message: String = "") {
#if DEBUG || DEV_DEBUG
    fatalError(message)
#else
    log(message)
#endif
}

func assertInDebug(_ conditional: Bool) {
#if DEV || DEV_DEBUG
    assert(conditional)
#endif
}

struct MathExpressionFormulaEdited: GraphEvent {
    let id: NodeId // pass the reference instead?
    let newExpression: String
    
    func handle(state: GraphState) {
        
        // Can fail when e.g. used in node view; that's okay.
        guard let node = state.getNodeViewModel(id) else {
            log("MathExpressionFormulaEdited: no math expression defined for node \(id)")
            return
        }
        
        assertInDebug(node.kind.getPatch == .mathExpression)
        
        node.updateMathExpressionNodeInputs(newExpression: newExpression)
        node.calculate()
    }
}

struct MathExpressionFocused: GraphUIEvent {
    let id: NodeId
    
    func handle(state: GraphUIState) {
        state.reduxFocusedField = .mathExpression(id)
    }
}

struct MathExpressionDefocused: GraphEventWithResponse {
    let id: NodeId
    
    func handle(state: GraphState) -> GraphResponse {
        if case state.graphUI.reduxFocusedField = .mathExpression(id) {
            state.graphUI.reduxFocusedField = nil
            return .persistenceResponse
        }
        return .noChange
    }
}

// ViewModifier only applied to NodeTitleView if the title is for a 
struct MathExpressionPopoverViewModifier: ViewModifier {
    
    let id: NodeId
    let mathExpression: String
    let isFocused: Bool // more like?: "is popover open"
    
    @State var show = false
    @State var expr = "" // Alternatively?: pass down a @Bindable mathExpression
    
    func body(content: Content) -> some View {
        
        content
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
