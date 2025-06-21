import Foundation
// Let's use the modules that are imported by the exploratory view
import SwiftUI
import SwiftSyntax
import SwiftParser

private func log(_ message: String) {
    print("[SwiftUIParser] \(message)")
}

// MARK: - SwiftUI Action Model

/// Direct representation of SwiftUI component operations
enum SwiftUIAction: CustomStringConvertible {
    case createContainer(id: String, type: String)
    case createView(id: String, type: String)
    case createText(id: String, initialText: String)
    case createShape(id: String, type: String)
    case setText(id: String, text: String)
    case setInput(id: String, input: String, value: String)
    case addChild(parentId: String, childId: String)

    var description: String {
        switch self {
        case .createContainer(let id, let type):
            return ".createContainer(id: \"\(id)\", type: \"\(type)\")"
        case .createView(let id, let type):
            return ".createView(id: \"\(id)\", type: \"\(type)\")"
        case .createText(let id, let initialText):
            return ".createText(id: \"\(id)\", initialText: \"\(initialText)\")"
        case .createShape(let id, let type):
            return ".createShape(id: \"\(id)\", type: \"\(type)\")"
        case .setText(let id, let text):
            return ".setText(id: \"\(id)\", text: \"\(text)\")"
        case .setInput(let id, let input, let value):
            return ".setInput(id: \"\(id)\", input: \"\(input)\", value: \"\(value)\")"
        case .addChild(let parentId, let childId):
            return ".addChild(parentId: \"\(parentId)\", childId: \"\(childId)\")"
        }
    }
}

// MARK: - SwiftUI Parser

class SwiftUIParser: SyntaxVisitor {
    private var actions: [SwiftUIAction] = []
    private var idCounter = 0
    
    // Stack to keep track of parent containers
    private var containerStack: [(id: String, type: String)] = []
    
    // Current node being processed
    private var currentNodeId: String = ""
    
    // Helper to find the root call in a modifier chain
    private func findRootCall(_ node: FunctionCallExprSyntax) -> FunctionCallExprSyntax {
        var current: Syntax = Syntax(node)
        while let member = current.parent?.as(MemberAccessExprSyntax.self),
              let parentCall = member.parent?.as(FunctionCallExprSyntax.self) {
            current = Syntax(parentCall)
        }
        return current.as(FunctionCallExprSyntax.self)!
    }
    
    // MARK: - Public Interface
    
    /// Parse SwiftUI code and return structured representation
    static func parse(_ swiftUICode: String) -> [SwiftUIAction] {
        let sourceFile = Parser.parse(source: swiftUICode)
        let visitor = SwiftUIParser(viewMode: .sourceAccurate)
        visitor.walk(sourceFile)
        return visitor.actions
    }
    
    // MARK: - Helper Methods
    
    private func generateId(prefix: String) -> String {
        let id = "\(prefix)\(idCounter)"
        idCounter += 1
        return id
    }
    
    // MARK: - Syntax Visitor
    
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        log("Visiting FunctionCallExpr: \(node.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines))")
        // Extract view type from function call
        var viewType: String?

        // Direct identifier, e.g. Text(), ZStack(), Rectangle()
        if let ident = node.calledExpression.as(IdentifierExprSyntax.self) {
            viewType = ident.identifier.text

        // Qualified SwiftUI.<View>
        } else if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
                  memberAccess.base?.as(IdentifierExprSyntax.self)?.identifier.text == "SwiftUI" {
            viewType = memberAccess.name.text

        // Member access without base, e.g. .padding (treat as view when base nil)
        } else if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
                  memberAccess.base == nil {
            viewType = memberAccess.name.text
        }
        
        log("Detected viewType: \(viewType ?? "nil")")
        // Process the view type
        if let viewType = viewType {
            // Determine if this is a container, shape, or regular view
            if isContainer(viewType) {
                log("Handling container view: \(viewType)")
                handleContainer(node, type: viewType)
            } else if isShape(viewType) {
                log("Handling shape view: \(viewType)")
                handleShape(node, type: viewType)
            } else if viewType == "Text" {
                log("Handling Text view")
                handleText(node)
            } else {
                log("Handling generic view: \(viewType)")
                // Generic view
                currentNodeId = generateId(prefix: viewType.lowercased())
                actions.append(.createView(id: currentNodeId, type: viewType))
            }

            // Process modifiers
            processModifiersFor(rootNode: node)

            return .skipChildren
        }

        return .visitChildren
    }
    
    // MARK: - View Type Handlers
    
    private func isContainer(_ viewType: String) -> Bool {
        return ["VStack", "HStack", "ZStack", "Group", "ScrollView", "List", "ForEach", "LazyVStack", "LazyHStack", "Form"].contains(viewType)
    }
    
    private func isShape(_ viewType: String) -> Bool {
        return ["Rectangle", "Circle", "RoundedRectangle", "Ellipse", "Capsule", "Path"].contains(viewType)
    }
    
    private func handleContainer(_ node: FunctionCallExprSyntax, type: String) {
        // Generate ID for container
        currentNodeId = generateId(prefix: type.lowercased())
        
        // Create action
        actions.append(.createContainer(id: currentNodeId, type: type))
        log("Created container \(type) with id \(currentNodeId)")
        
        // Push to stack
        containerStack.append((id: currentNodeId, type: type))
        
        if let closure = node.trailingClosure {
            log("Entering container closure for \(type)")
            let containerId = currentNodeId
            var addedChildren = Set<String>()

            for item in closure.statements {
                let syntax = item.item
                // Extract the initial FunctionCallExpr (e.g., Rectangle())
                var initializer: FunctionCallExprSyntax?
                if let fce = syntax.as(FunctionCallExprSyntax.self) {
                    initializer = fce
                } else if let exprStmt = syntax.as(ExpressionStmtSyntax.self),
                          let fce = exprStmt.expression.as(FunctionCallExprSyntax.self) {
                    initializer = fce
                }

                if let initCall = initializer {
                    log("Visiting initializer call: \(initCall.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines))")
                    // 1) Create the view node
                    _ = visit(initCall)
                    // 2) Apply its modifiers
                    processModifiersFor(rootNode: initCall)

                    let childId = currentNodeId
                    if !addedChildren.contains(childId) {
                        actions.append(.addChild(parentId: containerId, childId: childId))
                        addedChildren.insert(childId)
                        log("Added child \(childId) to parent \(containerId)")
                    } else {
                        log("Skipping duplicate child \(childId) for parent \(containerId)")
                    }
                } else {
                    log("NO FUNCTION CALL in closure item: '\(syntax.description.trimmingCharacters(in: .whitespacesAndNewlines))'")
                }
            }
        } else {
            log("NO node.trailingClosure for \(type)")
        }
        
        // Pop from stack
        containerStack.removeLast()
        
        // Restore parent ID if stack isn't empty
        if let parent = containerStack.last {
            currentNodeId = parent.id
        }
    }
    
    private func handleShape(_ node: FunctionCallExprSyntax, type: String) {
        currentNodeId = generateId(prefix: type.lowercased())
        actions.append(.createShape(id: currentNodeId, type: type))
    }
    
    private func handleText(_ node: FunctionCallExprSyntax) {
        currentNodeId = generateId(prefix: "text")
        actions.append(.createText(id: currentNodeId, initialText: ""))
        
        // Extract text content from first argument
        if let textArg = node.arguments.first?.expression.trimmedDescription {
            // Remove quotes from string literals
            let text = textArg.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            actions.append(.setText(id: currentNodeId, text: text))
        }
    }
    
    // MARK: - Modifier Processing

    private func processModifiersFor(rootNode: FunctionCallExprSyntax) {
        var mods: [(name: String, args: TupleExprElementListSyntax)] = []
        var current: Syntax = Syntax(rootNode)
        while let member = current.parent?.as(MemberAccessExprSyntax.self),
              let call = member.parent?.as(FunctionCallExprSyntax.self) {
            mods.append((name: member.name.text, args: call.argumentList))
            current = Syntax(call)
        }
        for mod in mods {
            let value = argumentsToString(mod.args)
            actions.append(.setInput(id: currentNodeId, input: mod.name, value: value))
        }
        let modifierNames = mods.map { $0.name }.joined(separator: ", ")
        log("Modifiers for \(currentNodeId): [\(modifierNames)]")
    }
    
    private func argumentsToString(_ arguments: TupleExprElementListSyntax) -> String {
        if arguments.isEmpty {
            return ""
        }
        
        return arguments.map { arg in
            var result = ""
            if let label = arg.label {
                result += "\(label.text): "
            }
            result += arg.expression.trimmedDescription
            return result
        }.joined(separator: ", ")
    }
}

// MARK: - Test Function

/// Parse a SwiftUI code snippet and output the actions
func parseSwiftUIToActions(_ swiftUICode: String) -> [SwiftUIAction] {
    return SwiftUIParser.parse(swiftUICode)
}

// Sample test with the example from USER
func testSwiftUIParser() {
    let src = #"""
    VStack {
      Text("salut").padding(16).border(.red)
    }.padding(8)
    """#
    
    let actions = parseSwiftUIToActions(src)
    print("Parsed SwiftUI Actions:")
    actions.forEach { print($0) }
}
