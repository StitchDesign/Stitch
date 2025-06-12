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
        // HACK to get tooltips working on Mac Catalyst; can't use SwiftUI `.help`
        ZStack {
            CatalystToolTipButton(systemImageName: systemName,
                                  tooltipText: toolTip) { }
            .fixedSize()
            
            Menu {
//                StitchButton {
//                    log("open modal")
//                } label: {
//                    Text("Create AI Node")
//                }
//                StitchButton {
//                    log("open node menu")
//                } label: {
//                    Text("Add Nodes")
//                }
                
                menuContentViews()
            } label: {
                EmptyView()
            }
            .modifier(CatalystTopBarButtonStyle())
        }
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
        
        // HACK to get tooltips working on Mac Catalyst; can't use SwiftUI `.help`
        ZStack {
            CatalystToolTipButton(systemImageName: systemName,
                                  tooltipText: toolTip) { }
            .fixedSize()
            
            Menu {
                // 'Empty menu' so that nothing happens when we tap the Menu's label
                EmptyView()
            } label: {
                EmptyView()
            }
            // rotation3DEffect must be applied here
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
            .modifier(CatalystTopBarButtonStyle())
            .simultaneousGesture(TapGesture().onEnded({ _ in
                action()
            }))
        }
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
