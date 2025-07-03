//
//  VarBodyCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/2/25.
//

import Foundation


struct VarBodyCodeExamples {
    static let var_body = MappingCodeExample(
        title: "var body",
        code: """
        struct ContentView: View {
            var body: some View {
                ZStack {
                    Image(systemName: "globe")
                        .foregroundColor(Color.red)
                    Text("Hello, world!")
                }
            }
        }
        """
    )

    static let var_body_method = MappingCodeExample(
        title: "var body + method",
        code: """
        struct ContentView: View {
        
            func myMethod() -> Bool {
                true
            }
        
            var body: some View {
                ZStack {
                    Image(systemName: "globe")
                        .foregroundColor(Color.red)
                    Text("Hello, world!")
                }
            }
        }
        """
    )

    static let file_views = MappingCodeExample(
        title: "File, views",
        code: """
        import SwiftUI
        
        struct ContentView: View {
            
            @State var myState: String = ""
            
            var myComputedVar: Bool {
                true
            }
            
            func myMethod() -> Int {
                1
            }
            
            var body: some View {
                ZStack {
                    Image(systemName: "globe")
                        .foregroundColor(Color.red)
                    Text("Hello, world!")
                }
            }
        
            var myView: some View {
                Rectangle()
            }
        }
        """
    )
}
