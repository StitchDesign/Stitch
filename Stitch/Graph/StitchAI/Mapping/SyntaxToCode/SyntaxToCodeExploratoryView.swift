//
//  SyntaxToCodeExploratoryView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import SwiftUI

struct SyntaxToCodeExploratoryView: View {
    // Tab selection
    @State private var selectedTab = 0
    @State private var generatedCode: String = ""
    @State private var viewNodeDescription: String = ""
    
    // All examples from StitchSyntax.swift
    let examples: [(name: String, viewNode: SyntaxView)] = [
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
        HStack(spacing: 20) {
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
                .frame(minHeight: 500)
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
            }
            .padding(.horizontal)
        }
    }
    
    private func updateDisplayForCurrentExample() {
        let selectedViewNode = examples[selectedTab].viewNode
        generatedCode = swiftUICode(from: selectedViewNode)
        viewNodeDescription = formatSyntaxView(selectedViewNode)
    }
}

#Preview {
    SyntaxToCodeExploratoryView()
}
