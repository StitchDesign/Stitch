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
        
        VStack {
            Text(self.debugLocation)
                .border(.blue, width: 2)
        }
        .border(.red, width: 2)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .named(GraphBaseView.coordinateNamespace)), initial: true) { _, newOrigin in
                        self.debugLocation = newOrigin.debugDescription
                    }
            }
        }
        .border(.green, width: 2)
        
        
    }
}
