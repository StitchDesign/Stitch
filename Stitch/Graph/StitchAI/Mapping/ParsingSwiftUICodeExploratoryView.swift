import SwiftUI
import StitchSchemaKit

struct ParsingSwiftUICodeExploratoryView: View {
    @State private var output: String = "Tap 'Parse Code' to begin..."
    @State private var testCases: [(name: String, code: String)] = [
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
        (name: "VStack with Views",
         code: """
        VStack {
            Text("Title")
                .font(.headline)
            Rectangle()
                .fill(Color.green)
                .frame(width: 200, height: 100)
        }
        .padding()
        """)
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
                ScrollView {
                    Text(testCases[selectedTestCase].code)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .frame(height: 150)
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
                        .background(Color(.systemGray6))
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
        
        let actions = parseSwiftUICodeToActions(code)
        result += "=== Found \(actions.count) actions ===\n\n"
        
        for (index, action) in actions.enumerated() {
            result += "[Action \(index + 1)] \(String(describing: type(of: action)))\n"
            let mirror = Mirror(reflecting: action)
            for child in mirror.children {
                if let label = child.label {
                    result += "  - \(label): \(child.value)\n"
                }
            }
            result += "\n"
            
            print("Action \(index + 1):", action)
        }
        
        result += "\nCheck console for detailed debug output"
        output = result
        
        print("\n=== Parser Finished ===")
    }
}

#Preview {
    ParsingSwiftUICodeExploratoryView()
}
