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
//    @State private var nodesViewSpaceLocation: String = "none"
    
    var body: some View {
        
//        VStack {
        ZStack {
            Rectangle().fill(.cyan.opacity(0.8))
                .frame(width: 100, height: 100)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: proxy.frame(in: .named(NodesView.coordinateNameSpace)),
//                            .onChange(of: proxy.frame(in: .global),
                                      initial: true) { _, newFrame in
                                log("LayerInspectorView: TEXT: onChangeOf frame: newFrame: \(newFrame)")
                                self.debugLocation = newFrame.debugDescription
                            }
                    }
                }
            
            Color.yellow.opacity(0.5)
                .border(.red, width: 4)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                        //                    .onChange(of: proxy.frame(in: .named(GraphBaseView.coordinateNamespace)),
                            .onChange(of: proxy.frame(in: .named(NodesView.coordinateNameSpace)),
                                      initial: true) { _, newFrame in
                                log("LayerInspectorView: YELLOW: onChangeOf frame: newFrame: \(newFrame)")
                                self.debugLocation = newFrame.debugDescription
                            }
                    }
                } // .background
        } // ZStack
        
    }
}
