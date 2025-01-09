//
//  DebugModePopover.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/8/25.
//

import SwiftUI

struct DebugModePopover: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        HStack {
            Image(systemName: ProjectContextMenuModifer.debugModeIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30)
                .foregroundStyle(theme.themeData.edgeColor)
            
            VStack(alignment: .leading) {
                Text("Welcome to Debug Mode")
                    .font(.headline)
                Text("Prototypes are paused to enable inspection of faults in your graph. This is useful for debugging hangs in your prototype. Root causes could include a high loop count in some node's input field.")
                    .font(.subheadline)
            }
            .frame(maxWidth: 520)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
}

#Preview {
    DebugModePopover()
}
