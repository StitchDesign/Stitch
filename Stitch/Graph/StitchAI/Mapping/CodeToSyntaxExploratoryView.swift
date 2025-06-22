//
//  CodeToSyntaxExploratoryView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import SwiftUI
import Foundation

// The project already has these types and functions imported
// We don't need explicit imports because they're part of the same module

struct CodeToSyntaxExploratoryView: View {
    // Tab selection
    @State private var selectedTab = 0
    @State private var swiftUICode: String = ""
    @State private var parsedViewNode: ViewNode? = nil
    
    // All examples from StitchSyntax.swift converted to SwiftUI code strings
    let examples: [(name: String, code: String)] = [
        ("Complex Modifier", "Rectangle()\n    .frame(width: 200, height: 100, alignment: .center)"),
        ("ZStack with Rectangles", "ZStack {\n    Rectangle()\n        .fill(Color.blue)\n    Rectangle()\n        .fill(Color.green)\n}"),
        ("Simple Text", "Text(\"salut\")"),
        ("Text with Modifiers", "Text(\"salut\")\n    .foregroundColor(Color.yellow)\n    .padding()"),
        ("Nested Views", "ZStack {\n    Rectangle()\n        .fill(Color.blue)\n    VStack {\n        Rectangle()\n            .fill(Color.green)\n        Rectangle()\n            .fill(Color.red)\n    }\n}"),
        ("Image Example", "Image(systemName: \"star.fill\")"),
    ]
    
    var body: some View {
        
        VStack(spacing: 10) {
            Text("SwiftUI Code to ViewNode Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
                   
            Button("Parse SwiftUI Code") {
                self.updateDisplayForCurrentExample()
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            // Tab bar
            TabView(selection: $selectedTab) {
                ForEach(0..<examples.count, id: \.self) { index in
                    exampleView(for: index)
                        .tabItem {
                            Text(examples[index].name)
                        }
                        .tag(index)
                }
            }
            .onChange(of: selectedTab) { _, _ in
                updateDisplayForCurrentExample()
            }
        }
        .padding()
        .onAppear {
            // Generate content for the first example on appearance
            updateDisplayForCurrentExample()
        }
    }
    
    private func exampleView(for index: Int) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SwiftUI Code:")
                    .font(.headline)
                
                ScrollView {
                    Text(self.swiftUICode)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
//                .frame(height: 300)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Parsed ViewNode Structure:")
                    .font(.headline)
                
                if let parsedNode = self.parsedViewNode {
                    ScrollView {
                        Text(formatViewNode(parsedNode))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 500)
                }
                
               
            }
            .padding(.horizontal)
           
        }
        .padding(.top)
    }
    
    private func updateDisplayForCurrentExample() {
        let selectedCode = self.examples[self.selectedTab].code
        self.swiftUICode = selectedCode
        
        // Parse the SwiftUI code to get the ViewNode representation
        let output = parseSwiftUICode(self.swiftUICode)
        self.parsedViewNode = output
    }
}

#Preview {
    CodeToSyntaxExploratoryView()
}
