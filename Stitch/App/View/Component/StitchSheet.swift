//
//  StitchSheet.swift
//  prototype
//
//  Created by Elliot Boschwitz on 5/23/22.
//

import SwiftUI
import StitchSchemaKit

extension View {
    /// Calls a view modifier providing a standard sheet view. Helps us abstract away common sheet actions and styling.
    func stitchSheet<T: View>(isPresented: Bool,
                              titleLabel: String,
                              hideAction: Action,
                              @ViewBuilder sheetBody: () -> T) -> some View {
        return self.modifier(SheetViewModifier(isPresented: isPresented,
                                               titleLabel: titleLabel,
                                               hideAction: hideAction,
                                               sheetBody: sheetBody))
    }
}

struct SheetViewModifier<T: View>: ViewModifier {
    let isPresented: Bool
    let titleLabel: String
    let hideAction: Action
    let sheetBody: T

    init(isPresented: Bool,
         titleLabel: String,
         hideAction: Action,
         @ViewBuilder sheetBody: () -> T) {
        self.isPresented = isPresented
        self.titleLabel = titleLabel
        self.hideAction = hideAction
        self.sheetBody = sheetBody()
    }

    // TODO: background selections for Catalyst (GitHub issue #814)
    func body(content: Content) -> some View {
        let isPresentedBinding = createBinding(isPresented) {
            if !$0 {
                dispatch(hideAction)
            }
        }

        content
            .sheet(isPresented: isPresentedBinding) {
                StitchHostingControllerView(ignoreKeyCommands: false,
                                            name: "SheetViewModifier") {
                    VStack(alignment: .leading) {
                        titleView
                        sheetBody
                            .padding()
                        Spacer()
                    }
                    .padding()
                    .background(
                        Color(uiColor: .systemGray5)
                            // NOTE: strangely we need `[.all, .keyboard]` on BOTH the background color AND the StitchHostingControllerView
                            .ignoresSafeArea([.all, .keyboard])
                    )
                }.ignoresSafeArea([.all, .keyboard])
            }
    }

    @MainActor
    var titleView: some View {
        ZStack {
            HStack {
                Spacer()
            }
            Text(titleLabel)
                .fontWeight(.heavy)
            HStack {
                Spacer()
                StitchButton {
                    dispatch(hideAction)
                } label: {
                    Text("Done")
                        .fontWeight(.bold)
                }
            }
        }
    }
}
