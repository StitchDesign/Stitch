//
//  CatalystNavBarButtonView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/25.
//

import SwiftUI

struct CatalystNavBarButtonWithMenu<MenuContentView: View>: View {
    let systemName: String
    let toolTip: String
    @ViewBuilder var menuContentViews: () -> MenuContentView
    
    var body: some View {
        Menu {
            menuContentViews()
        } label: {
            Button(toolTip,
                   systemImage: systemName,
                   action: { })
            .controlSize(.extraLarge)
        }
        .menuIndicator(.hidden)
    }
}

// Hacky view to get hover effect on Catalyst topbar buttons and to enforce gray tint
struct CatalystNavBarButton: View {

    init(_ systemName: String,
         toolTip: String,
         rotationZ: CGFloat = 0,
         _ action: @escaping () -> Void) {
        self.systemName = systemName
        self.toolTip = toolTip
        self.action = action
        self.rotationZ = rotationZ
    }
    
    let systemName: String
    let toolTip: String

    // Only the graph-reset icon rotates?
    var rotationZ: CGFloat = 0
    
    let action: () -> Void
        
    var body: some View {
        Button(toolTip,
               systemImage: systemName,
               action: action)
        .rotation3DEffect(Angle(degrees: rotationZ),
                          axis: (x: 0, y: 0, z: rotationZ))
        .controlSize(.extraLarge)
    }
}

struct CatalystTopBarButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
        // Hides the little arrow on Catalyst
        .menuIndicator(.hidden)
        
        // TODO: find ideal button size?
        // Note: *must* provide explicit frame
        .frame(width: 30, height: 30)
    }
}
