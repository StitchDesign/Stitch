//
//  SyntaxToCodeExploratoryView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import SwiftUI

// Since all files are in the same project, we can directly access ViewNode, Modifier, and the examples from StitchSyntax
// and the swiftUICode function from CodeToStitchSyntax without explicit imports

struct SyntaxToCodeExploratoryView: View {
    // Tab selection
    @State private var selectedTab = 0
    @State private var generatedCode: String = ""
    @State private var viewNodeDescription: String = ""
    
    // All examples from StitchSyntax.swift
    let examples: [(name: String, viewNode: ViewNode)] = [
        ("Complex Modifier", complexModifierExample),
        ("ZStack with Rectangles", example1),
        ("Simple Text", example2),
        ("Text with Modifiers", example3),
        ("Nested Views", example4),
        ("Image Example", example5)
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Text("ViewNode to SwiftUI Code Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
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
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ViewNode Structure:")
                    .font(.headline)
                
                ScrollView {
                    Text(viewNodeDescription)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .frame(height: 800)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Generated SwiftUI Code:")
                    .font(.headline)
                
                ScrollView {
                    Text(generatedCode)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
//                .frame(height: 500)
            }
            .padding(.horizontal)
            
//            Spacer()
        }
        .padding(.top)
    }
    
    private func updateDisplayForCurrentExample() {
        let selectedViewNode = examples[selectedTab].viewNode
        generatedCode = swiftUICode(from: selectedViewNode)
        viewNodeDescription = formatViewNode(selectedViewNode)
    }
    
    // Formats a ViewNode into a readable string representation
    private func formatViewNode(_ node: ViewNode, indent: String = "") -> String {
        var result = "\(indent)ViewNode("
        result += "\n\(indent)    name: \"\(node.name)\","
        
        // Format arguments
        result += "\n\(indent)    arguments: ["
        if !node.arguments.isEmpty {
            for (i, arg) in node.arguments.enumerated() {
                let label = arg.label != nil ? "\"\(arg.label!)\"" : "nil"
                result += "\n\(indent)        (label: \(label), value: \(arg.value))"
                if i < node.arguments.count - 1 {
                    result += ","
                }
            }
            result += "\n\(indent)    ],"
        } else {
            result += "],"
        }
        
        // Format modifiers
        result += "\n\(indent)    modifiers: ["
        if !node.modifiers.isEmpty {
            for (i, modifier) in node.modifiers.enumerated() {
                result += "\n\(indent)        Modifier("
                result += "\n\(indent)            name: \"\(modifier.name)\","
                result += "\n\(indent)            value: \"\(modifier.value)\","
                
                // Format modifier arguments
                result += "\n\(indent)            arguments: ["
                if !modifier.arguments.isEmpty {
                    for (j, arg) in modifier.arguments.enumerated() {
                        let label = arg.label != nil ? "\"\(arg.label!)\"" : "nil"
                        result += "\n\(indent)                (label: \(label), value: \"\(arg.value)\")"
                        if j < modifier.arguments.count - 1 {
                            result += ","
                        }
                    }
                    result += "\n\(indent)            ]"
                } else {
                    result += "]"
                }
                
                result += "\n\(indent)        )"
                if i < node.modifiers.count - 1 {
                    result += ","
                }
            }
            result += "\n\(indent)    ],"
        } else {
            result += "],"
        }
        
        // Format children recursively
        result += "\n\(indent)    children: ["
        if !node.children.isEmpty {
            for (i, child) in node.children.enumerated() {
                result += "\n" + formatViewNode(child, indent: indent + "        ")
                if i < node.children.count - 1 {
                    result += ","
                }
            }
            result += "\n\(indent)    ],"
        } else {
            result += "],"
        }
        
        // Add ID
        result += "\n\(indent)    id: \"\(node.id)\""
        result += "\n\(indent))"
        
        return result
    }
}

#Preview {
    SyntaxToCodeExploratoryView()
}
