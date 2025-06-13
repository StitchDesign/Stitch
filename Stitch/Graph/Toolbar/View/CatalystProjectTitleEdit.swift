//
//  CatalystProjectTitleEdit.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/25.
//

import SwiftUI


struct CatalystProjectTitleModalOpened: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("CatalystProjectTitleModalOpened")
        withAnimation {
            state.showCatalystProjectTitleModal = true
        }
        state.reduxFieldFocused(focusedField: .projectTitle)
    }
}

struct CatalystProjectTitleModalClosed: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("CatalystProjectTitleModalClosed")
        withAnimation {
            state.showCatalystProjectTitleModal = false
        }
        state.reduxFieldDefocused(focusedField: .projectTitle)
    }
}

struct CatalystProjectTitleModalView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @FocusState var focus: Bool
    
    var body: some View {
        TextField("", text: $graph.name)
            .focused(self.$focus)
            .autocorrectionDisabled()
            .modifier(SelectAllTextViewModifier())
            .modifier(NavigationTitleFontViewModifier())
            .onAppear {
                // log("CatalystProjectTitleModalView: onAppear")
                self.focus = true
            }
            .onChange(of: self.document.reduxFocusedField == .projectTitle, initial: true) { oldValue, newValue in
                // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): oldValue: \(oldValue)")
                // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): newValue: \(newValue)")
                if !newValue {
                    // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): will set focus false")
                    self.focus = false
                } else {
                    // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): will set focus true")
                    self.focus = true
                }
            }
        // Do not use `initial: true`
            .onChange(of: self.focus) { oldValue, newValue in
                // log("CatalystProjectTitleModalView: .onChange(of: self.focus): oldValue: \(oldValue)")
                // log("CatalystProjectTitleModalView: .onChange(of: self.focus): newValue: \(newValue)")
                if newValue {
                    dispatch(ReduxFieldFocused(focusedField: .projectTitle))
                } else {
                    // log("CatalystNavBarTitleEditField: defocused, so will commit")
                    graph.name = graph.name.validateProjectTitle()
                    dispatch(ReduxFieldDefocused(focusedField: .projectTitle))
                    dispatch(CatalystProjectTitleModalClosed())
                    // Commit project name to disk
                    graph.encodeProjectInBackground()
                }
            }
    }
}

// Imitates the .navigationTitle($someBinding) edit experience on iPad
struct CatalystNavBarProjectTitleDisplayView: View {
    @Bindable var graph: GraphState
    
    var body: some View {
        Text(graph.name)
            .modifier(NavigationTitleFontViewModifier())
            .padding(6)
            .frame(width: 260, height: 16, alignment: .leading)
            .onTapGesture {
                dispatch(CatalystProjectTitleModalOpened())
            }
    }
}

struct NavigationTitleFontViewModifier: ViewModifier {

    // imitates .navigationTitle font weight
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .bold()
    }
}

/// When we first begin editing a TextField, auto-select all text
struct SelectAllTextViewModifier: ViewModifier {

    // `content` should be a `TextField`
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(
                        for: UITextField.textDidBeginEditingNotification)) { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                    )
                }
            }
    }
}
