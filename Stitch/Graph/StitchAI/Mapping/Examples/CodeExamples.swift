//
//  MappingCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/26/25.
//

import Foundation


// Just a namespace
struct MappingExamples { }

extension MappingExamples {
    
    // TODO: break into separate pieces
    static let codeExamples: [(title: String, code: String)] = [
       
        ("Position", """
         Rectangle()
             .position(x: 200, y: 200)
         """),
        
        ("Offset", """
         Rectangle()
             .offset(x: 200, y: 200)
         """),
        
        ("RoundedRectangle", """
         RoundedRectangle(cornerRadius: 25)
         """),
        
        ("Frame", """
         Rectangle()
             .frame(width: 200, height: 100)
         """),
        
        ("Text", #"Text("salut")"#),
        
        ("Text with color", #"Text("salut").foregroundColor(Color.yellow).padding()"#),
        
        ("Image", #"Image(systemName: "star.fill")"#),
        
        ("ZStack Rectangles", """
         ZStack {
             Rectangle().fill(Color.blue)
             Rectangle().fill(Color.green)
         }
         """),
       
        // TODO: JUNE 26: CURRENTLY BACK-CONVERTED PROPERLY ?
        ("ZStack with modifier", """
         ZStack {
             Rectangle()
                .fill(Color.blue)
         }.scaleEffect(2)
         """),
        
        ("VStack", """
         VStack {
            Rectangle().fill(Color.blue)
         }
         """),
        
        ("Nested", """
         ZStack {
             Rectangle().fill(Color.blue)
             VStack {
                 Rectangle().fill(Color.green)
                 Rectangle().fill(Color.red)
             }
         }
         """),
        
        ("Nested with scale", """
         ZStack {
             Rectangle().fill(Color.blue)
             VStack {
                 Rectangle().fill(Color.green)
                 Rectangle().fill(Color.red)
             }
         }.scaleEffect(4)
         """),
        
        ("var body", """
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
        ),
        
        ("var body + method", """
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
        ),
        
        
        ("File, views", """
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
    ]
}
