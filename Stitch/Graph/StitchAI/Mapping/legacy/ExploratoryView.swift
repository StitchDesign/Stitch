import SwiftUI
import StitchSchemaKit

// Import our custom SwiftUI syntax mapping
import SwiftParser
import SwiftSyntax


struct ExploratoryView: View {
    @State private var output: String = "Tap 'Parse Code' to begin..."
    @State private var testCases: [(name: String, code: String)] = [
       

        (name: "Nested 1",
         code: """
        ZStack {
            Text("Title")
            VStack {
                Rectangle()
                Rectangle()
            }
        }   
        """),

        (name: "Nested 2",
         code: """
        ZStack {
            Text("Title")
            VStack {
                Rectangle().fill(.red)
                Rectangle().fill(.green)
            }
        }   
        """),

        (name: "ZStack with Views",
         code: """
        ZStack {
            Text("Title")
            Rectangle()
        }
        .padding()
        .frame(width: 200, height: 100)
        """),
        
        (name: "ZStack with children with modifiers",
         code: """
        ZStack {
            Text("Title")
            Rectangle().fill(Color.green)
        }
        .padding()        
        """),
        
        (name: "VStack with Views",
         code: """
        VStack {
            Text("Title")
            Rectangle()
                .fill(Color.green)
                .frame(width: 200, height: 100)
        }
        .padding()
        """),
        
        (name: "Rectangle with .frame",
         code: """
            Rectangle()
                .frame(width: 200, height: 100)
        """),
        
        (name: "Simple ZStack ",
         code: """
        ZStack {
            Rectangle()
        }
        """),
        
        (name: "ZStack with Views 2",
         code: """
        ZStack {
            Text("Title")
            Rectangle()
        }
        
        ZStack {
            Oval()
            Oval()
        }
        """),
        
        (name: "Simple Rectangle",
         code: """
        Rectangle()
            .fill(Color.blue)
            .opacity(0.5)
        """),
        
        (name: "Text View",
         code: """
        Text("Hello, World!")
            .foregroundColor(.red)
        """),
        
       
    ]
    
    @State private var selectedTestCase = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Test case selector
            Picker("Test Case", selection: $selectedTestCase) {
                ForEach(0..<testCases.count, id: \.self) { index in
                    Text(testCases[index].name).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Code editor
            VStack(alignment: .leading) {
                Text("SwiftUI Code:")
                    .font(.headline)
                
                // Create a binding for the current test case code
                let codeBinding = Binding<String>(
                    get: { self.testCases[self.selectedTestCase].code },
                    set: { self.testCases[self.selectedTestCase].code = $0 }
                )
                
                // Editable code area
                TextEditor(text: codeBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            // Parse button
            Button(action: parseCode) {
                Text("Parse Code")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // Output
            VStack(alignment: .leading) {
                Text("Output:")
                    .font(.headline)
                ScrollView {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func parseCode() {
        
        
        
        let code = testCases[selectedTestCase].code
        var result = "=== Parsing ===\n\(code)\n\n"
        
        print("\n=== Starting Parser ===")
        print("Code to parse:", code)
        
        // Use the new SwiftUIParser from SwiftUISyntaxMapping.swift
        let actions = parseSwiftUIToActions(code)
        
        result += "=== Found \(actions.count) actions ===\n\n"
        
        for (index, action) in actions.enumerated() {
            result += "[Action \(index + 1)] \(action)\n"
            
            // Add more details based on the action type
            switch action {
            case .createContainer(let id, let type):
                result += "  Created container: \(type) with ID: \(id)\n"
            case .createText(let id, let initialText):
                result += "  Created text with ID: \(id)\(initialText.isEmpty ? "" : " and initial text: \(initialText)")\n"
            case .setText(let id, let text):
                result += "  Set text for ID: \(id) to: \(text)\n"
            case .createShape(let id, let type):
                result += "  Created shape: \(type) with ID: \(id)\n"
            case .createView(let id, let type):
                result += "  Created view: \(type) with ID: \(id)\n"
            case .setInput(let id, let input, let value):
                result += "  Set input: \(input) = \(value) for ID: \(id)\n"
            case .addChild(let parentId, let childId):
                result += "  Added child: \(childId) to parent: \(parentId)\n"
            }
            
            result += "\n"
            print("Action \(index + 1):", action)
        }
        
        result += "\nCheck console for detailed debug output"
        output = result
        
        print("\n=== Parser Finished ===")
        
//        myTest()
    }
}

#Preview {
    ExploratoryView()
}
