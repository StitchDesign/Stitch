//
//  LogViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LogExportLoadingView: ViewModifier {

    let preparingLogs: Bool
    @State private var willAnimateInLoadingIndicator = false

    func body(content: Content) -> some View {
        return content
            .overlay {
                if willAnimateInLoadingIndicator {
                    GeometryReader { geometry in
                        VStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding()
                            Text("Loading Logs")
                                .bold()
                        }
                        .frame(geometry.size)
                        .background(APP_BACKGROUND_COLOR.opacity(0.9))
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                preparingLogsUpdated(willPrepareLogs: self.preparingLogs)
            }
            .onChange(of: preparingLogs) { willPrepareLogs in
                preparingLogsUpdated(willPrepareLogs: willPrepareLogs)
            }
    }

    @MainActor
    func preparingLogsUpdated(willPrepareLogs: Bool) {
        withAnimation {
            willAnimateInLoadingIndicator = willPrepareLogs
        }

        if !willPrepareLogs {
            dispatch(HideLogPreparationSheet())
        }
    }
}

struct LogExportLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            HStack {}
                .frame(geometry.size)
                .background(.gray)
                .modifier(LogExportLoadingView(preparingLogs: true))
        }
        .previewDevice("iPad Pro (11-inch) (3rd generation)")
    }
}

struct LogShareViewModifier: ViewModifier {

    let logEntriesURL: LogEntriesURL?

    func body(content: Content) -> some View {

        if let logEntriesURL = logEntriesURL {
            let binding = Binding<Bool>.init {
                return true
            } set: { newValue in
                log("LogShareViewModifier: binding: set: newValue: \(newValue)")
                dispatch(LogsSuccessfullyExported())
            }

            return content.sheet(isPresented: binding) {
                ActivityViewController(activityItems: [logEntriesURL.url])
            }.eraseToAnyView()

        } else {
            return content.eraseToAnyView()
        }
    }
}
