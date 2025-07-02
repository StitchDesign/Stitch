//
//  MappingCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/26/25.
//

import Foundation
import SwiftUI

// Just a namespace
struct MappingExamples { }

// helpful for writing
#if DEV_DEBUG
struct ExampleView: View {
    var body: some View {
        Color.yellow
    } // var body: some View
}
#endif

struct MappingCodeExample: Sendable {
    let title: String
    let code: String
}

let colorAsValue = MappingCodeExample(
    title: "color as value",
    code:
"""
Rectangle()
    .fill(Color("yellow") as! String)
"""
)

let colorAsView = MappingCodeExample(
    title: "color as view",
    code:
"""
Color.yellow
"""
)



extension MappingExamples {
    
    // TODO: break into separate pieces
    static let codeExamples: [MappingCodeExample] = [
        
        //        colorAsValue,
        //        colorAsView,
        
        // ScrollView
//        scrollViewVStack,
//        scrollViewHStack,
//        scrollViewNotTopLevel,
//        scrollViewWithAllAxes,
//        scrollViewWithoutExplicitAxes,
        
        MappingCodeExample(
            title: "VStack",
            code: """
            VStack {
                Rectangle().fill(Color.blue)
            }
            """
        ),
        
        MappingCodeExample(
            title: "Position",
            code: """
            Rectangle()
                .position(x: 200, y: 200)
            """
        ),
        
        MappingCodeExample(
            title: "Offset",
            code: """
            Rectangle()
                .offset(x: 200, y: 200)
            """
        ),
        
        MappingCodeExample(
            title: "RoundedRectangle",
            code: "RoundedRectangle(cornerRadius: 25)"
        ),
        
        MappingCodeExample(
            title: "Frame",
            code: """
            Rectangle()
                .frame(width: 200, height: 100)
            """
        ),
        
        MappingCodeExample(
            title: "Text",
            code: #"Text("salut")"#
        ),
        
        MappingCodeExample(
            title: "Text with color",
            code: #"Text("salut").foregroundColor(Color.yellow).padding()"#
        ),
        
        MappingCodeExample(
            title: "Image",
            code: #"Image(systemName: "star.fill")"#
        ),
        
        MappingCodeExample(
            title: "ZStack Rectangles",
            code: """
            ZStack {
                Rectangle().fill(Color.blue)
                Rectangle().fill(Color.green)
            }
            """
        ),
       
        MappingCodeExample(
            title: "ZStack with modifier",
            code: """
            ZStack {
                Rectangle()
                   .fill(Color.blue)
            }.scaleEffect(2)
            """
        ),
        
        MappingCodeExample(
            title: "Nested",
            code: """
            ZStack {
                Rectangle().fill(Color.blue)
                VStack {
                    Rectangle().fill(Color.green)
                    Rectangle().fill(Color.red)
                }
            }
            """
        ),

//        MappingCodeExample(
//            title: "Nested with scale",
//            code: """
//            ZStack {
//                Rectangle().fill(Color.blue)
//                VStack {
//                    Rectangle().fill(Color.green)
//                    Rectangle().fill(Color.red)
//                }
//            }.scaleEffect(4)
//            """
//        ),
        
//        MappingCodeExample(
//            title: "var body",
//            code: """
//            struct ContentView: View {
//                var body: some View {
//                    ZStack {
//                        Image(systemName: "globe")
//                            .foregroundColor(Color.red)
//                        Text("Hello, world!")
//                    }
//                }
//            }
//            """
//        ),
        
//        MappingCodeExample(
//            title: "var body + method",
//            code: """
//            struct ContentView: View {
//                var body: some View {
//                    ZStack {
//                        Image(systemName: "globe")
//                            .foregroundColor(Color.red)
//                        Text("Hello, world!")
//                    }
//                }
//            }
//            """
//        ),
//        
//        MappingCodeExample(
//            title: "File, views",
//            code: """
//            import SwiftUI
//
//            struct ContentView: View {
//                
//                @State var myState: String = ""
//                
//                var myComputedVar: Bool {
//                    true
//                }
//                
//                func myMethod() -> Int {
//                    1
//                }
//                
//                var body: some View {
//                    ZStack {
//                        Image(systemName: "globe")
//                            .foregroundColor(Color.red)
//                        Text("Hello, world!")
//                    }
//                }
//
//                var myView: some View {
//                    Rectangle()
//                }
//            }
//            """
//        ),
        
        // Rotation modifier
        rotationEffectBasic,
//        rotationEffectAnchor,
//        rotationEffectRadians,
        rotation3DEffectBasic,
//        rotation3DEffectPerspective
    ]
}
