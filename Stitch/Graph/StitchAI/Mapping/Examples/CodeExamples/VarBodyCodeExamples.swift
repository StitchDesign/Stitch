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
        code:
"""
struct ContentView: View {
    var body: some View {
        HStack {
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
        code:
"""
struct ContentView: View {

    let x = 1

    func myMethod() -> Int {
        1
    }

    var body: some View {
        HStack {
            HStack {
                Text("Title")
                Ellipse().frame(width: 120, height: 30)
            }
            VStack {
                Image(systemName: "star.fill")
                    .foregroundColor(Color.blue)
                Text("Some text here")
                    .opacity(0.5)
                Text("More text here")
                    .scaleEffect(1 + 2)
            }
        }
    }
}
"""
    )

    static let file_views = MappingCodeExample(
        title: "File, views",
        code:
"""
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
        Group {
            Image(systemName: "globe")
            Text("Bonjour")
        }
        .scaleEffect(9 * 0.1)
    }

    var myView: some View {
        Rectangle()
    }
}
"""
    )
    
    static let phone_dial = MappingCodeExample(
        title: "Phone Dial",
        code:
"""
import SwiftUI

struct VanilliaPhoneDialView: View {
    var body: some View {
        VStack {

            Text("1 (234) 567-8900")
            Text("Add Number")
            
            VStack {
                ForEach(0..<4) { row in
                    HStack {
                        ForEach(0..<3) { col in
                            ZStack {
                                Circle()
                                VStack {
                                    Text("N")
                                        .foregroundColor(.white)
                                } // VStack
                            } // ZStack
                        } // ForEach
                    } // HStack
                } // ForEach
            } // VStack
            
            HStack {
                Circle().overlay(Image(systemName: "phone.fill").foregroundColor(.white))
                ZStack {
                    Rectangle()
                    Image(systemName: "delete.left").foregroundColor(.white)
                } // ZStack
            } // HStack

        } // VStack

    } // body
    
    func updateLayerInputs() {
        // No dynamic state to update
    }
}

"""
    )
    
}


