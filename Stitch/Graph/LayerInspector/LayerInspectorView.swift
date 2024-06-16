//
//  LayerInspectorView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/16/24.
//

import Foundation
import SwiftUI

struct LayerInspectorView: View {
    @State private var debugLocation: String = "none"
    
    var body: some View {
        GeometryReader { proxy in
            Text(self.debugLocation)
                .onChange(of: proxy.frame(in: .named(GraphBaseView.coordinateNamespace)), initial: true) { _, newOrigin in
                    self.debugLocation = newOrigin.debugDescription
                }
        }
    }
}
