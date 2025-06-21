import SwiftUI
import Foundation
import SwiftSyntax
import SwiftParser
import StitchSchemaKit


let restrictedScopeSwiftUIJSON = """
{
  "inputs" : {
    "Blend Mode" : ".blendMode",
    "Blur" : ".blur",
    "Blur Radius" : ".blur",
    "Brightness" : ".brightness",
    "Clipped" : ".clipped",
    "Color" : ".fill",
    "Color Invert" : ".colorInvert",
    "Contrast" : ".contrast",
    "Corner Radius" : ".cornerRadius",
    "Hue Rotation" : ".hueRotation",
    "Opacity" : ".opacity",
    "Padding" : ".padding",
    "Position" : ".position",
    "Saturation" : ".saturation",
    "Scale" : ".scaleEffect",
    "Size" : ".frame",
    "Z Index" : ".zIndex"
  },
  "layers" : {
    "Oval" : "Ellipse",
    "Rectangle" : "Rectangle",
    "Text" : "Text"
  }
}
"""

/*
 Goal: turn these SwiftUI code snippets into graph steps.
 
 Approach:
 1. Parse the code into a syntax tree
 2. Map the syntax tree to a graph step
 */

let test0 = """
Rectangle.fill(Color.blue).opacity(0.5)
"""

// Example: Convert test0 SwiftUI code to StepActions

// MARK: - SwiftUI to StitchAI Parser

class SwiftUIToStitchAIVisitor: SyntaxVisitor {
    // Helper to find the topmost FunctionCallExprSyntax ancestor (root of the call chain)
    private func findRootCall(_ node: FunctionCallExprSyntax) -> FunctionCallExprSyntax {
        var current: Syntax = Syntax(node)
        while let member = current.parent?.as(MemberAccessExprSyntax.self),
              let parentCall = member.parent?.as(FunctionCallExprSyntax.self) {
            current = Syntax(parentCall)
        }
        return FunctionCallExprSyntax(current)!
    }
    var actions: [any StepActionable] = []
    private var currentNodeId: UUID = UUID()
    private var currentModifierChain: [FunctionCallExprSyntax] = []
    
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        print("\n=== Processing function call ===")
        print("Full node: \(node.description.trimmingCharacters(in: .whitespacesAndNewlines))")
        print("Called expression: \(node.calledExpression.trimmedDescription)")

        // Detect a top‐level view constructor (e.g. Rectangle() or Text())
        var viewType: String?
        if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self),
           memberAccess.base == nil {
            viewType = memberAccess.name.text
        } else if let identifier = node.calledExpression.as(IdentifierExprSyntax.self) {
            viewType = identifier.identifier.text
        }

        if let viewType = viewType {
            print("Found view type: \(viewType)")
            switch viewType {
            case "Rectangle":
                let addRectangle = StepActionAddNode(
                    nodeId: currentNodeId,
                    nodeName: .layer(.rectangle)
                )
                actions.append(addRectangle)
                print("Created StepActionAddNode for Rectangle")
            case "Text":
                let addText = StepActionAddNode(
                    nodeId: currentNodeId,
                    nodeName: .layer(.text)
                )
                actions.append(addText)
                print("Created StepActionAddNode for Text")
            default:
                print("Unhandled view type: \(viewType)")
                return .skipChildren
            }
            // Now process any chained modifiers on this view call
            let rootCall = findRootCall(node)
            processModifiers(rootCall)
            return .skipChildren
        }

        // (simple modifiers block removed)

        // If this is part of a modifier chain, collect it
        currentModifierChain.append(node)

        // Continue visiting children to build the full chain
        return .visitChildren
    }
    
    private func processModifiers(_ node: FunctionCallExprSyntax) {
        print("\n=== Processing modifiers ===")
        
        // Process the current node and any chained calls
        var currentNode: ExprSyntax = ExprSyntax(node)
        
        while let functionCall = FunctionCallExprSyntax(currentNode) {
            print("\nProcessing modifier: \(functionCall.calledExpression.trimmedDescription)")
            
            // Handle different types of modifiers
            if let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) {
                let modifierName = memberAccess.name.text
                print("Found modifier: \(modifierName)")
                
                switch modifierName {
                case "fill":
                    processFillModifier(functionCall)
                case "opacity":
                    processOpacityModifier(functionCall)
                case "blendMode":
                    processBlendModeModifier(functionCall)
                case "blur":
                    processBlurModifier(functionCall)
                case "brightness":
                    processBrightnessModifier(functionCall)
                case "clipped":
                    processClippedModifier(functionCall)
                case "colorInvert":
                    processColorInvertModifier(functionCall)
                case "contrast":
                    processContrastModifier(functionCall)
                case "cornerRadius":
                    processCornerRadiusModifier(functionCall)
                case "hueRotation":
                    processHueRotationModifier(functionCall)
                case "padding":
                    processPaddingModifier(functionCall)
                case "position":
                    processPositionModifier(functionCall)
                case "scaleEffect":
                    processScaleEffectModifier(functionCall)
                case "frame":
                    processFrameModifier(functionCall)
                case "zIndex":
                    processZIndexModifier(functionCall)
                default:
                    print("Unhandled modifier: \(modifierName)")
                }
            }
            
            // Move to the next chained call if it exists
            if let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self),
               let base = memberAccess.base {
                currentNode = base
            } else {
                break
            }
        }
    }
    
    private func processFillModifier(_ node: FunctionCallExprSyntax) {
        print("Processing fill modifier")
        
        // Extract color from fill(Color.blue)
        guard let firstArg = node.argumentList.first?.expression else {
            print("No arguments for fill modifier")
            return
        }
        
        let colorExpr = firstArg.description.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Color expression: \(colorExpr)")
        
        // Simple color extraction - handle Color.blue, .blue, etc.
        let colorName: String
        if colorExpr.hasPrefix("Color.") {
            colorName = String(colorExpr.dropFirst(6))
        } else if colorExpr.hasPrefix(".") {
            colorName = String(colorExpr.dropFirst())
        } else {
            colorName = colorExpr
        }
        
        let color: Color
        switch colorName.lowercased() {
        case "blue": color = .blue
        case "red": color = .red
        case "green": color = .green
        case "black": color = .black
        case "white": color = .white
        default: color = .black  // Default to black for unknown colors
        }
        
        print("Setting fill color: \(color)")
        
        let setFill = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .color,
                portType: .packed
            )),
            value: .color(color),
            valueType: .color
        )
        actions.append(setFill)
    }
    
    private func processOpacityModifier(_ node: FunctionCallExprSyntax) {
        print("Processing opacity modifier")
        
        guard let firstArg = node.argumentList.first?.expression else {
            print("No arguments for opacity modifier")
            return
        }
        
        let opacityString = firstArg.description.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Opacity value: \(opacityString)")
        
        guard let opacityValue = Double(opacityString) else {
            print("Invalid opacity value: \(opacityString)")
            return
        }
        
        print("Setting opacity: \(opacityValue)")
        
        let setOpacity = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .opacity,
                portType: .packed
            )),
            value: .number(opacityValue),
            valueType: .number
        )
        actions.append(setOpacity)
    }
}

// MARK: - Modifier Handlers
extension SwiftUIToStitchAIVisitor {
    // MARK: - Visual Effects
    private func processBlendModeModifier(_ node: FunctionCallExprSyntax) {
        guard let firstArg = node.argumentList.first?.expression.trimmedDescription else { return }
        let blendMode = firstArg.replacingOccurrences(of: ".", with: "")
        print("Setting blend mode: \(blendMode)")
        
        // Map to appropriate blend mode value
        let setBlendMode = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .blendMode,
                portType: .packed
            )),
            value: .blendMode(StitchBlendMode(rawValue: blendMode) ?? .defaultBlendMode),
            valueType: .blendMode
        )
        actions.append(setBlendMode)
    }
    
    private func processBlurModifier(_ node: FunctionCallExprSyntax) {
        guard let radiusArg = node.argumentList.first?.expression else { return }
        let radius = radiusArg.trimmedDescription
        if let radiusValue = Double(radius) {
            let setBlur = StepActionSetInput(
                nodeId: currentNodeId,
                port: .keyPath(.init(
                    layerInput: .blurRadius,
                    portType: .packed
                )),
                value: .number(radiusValue),
                valueType: .number
            )
            actions.append(setBlur)
        }
    }
    
    private func processBrightnessModifier(_ node: FunctionCallExprSyntax) {
        processNumericModifier(node, input: .brightness)
    }
    
    private func processClippedModifier(_ node: FunctionCallExprSyntax) {
        let setClipped = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .clipped,
                portType: .packed
            )),
            value: .bool(true),
            valueType: .bool
        )
        actions.append(setClipped)
    }
    
    private func processColorInvertModifier(_ node: FunctionCallExprSyntax) {
        let setInvert = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .colorInvert,
                portType: .packed
            )),
            value: .bool(true),
            valueType: .bool
        )
        actions.append(setInvert)
    }
    
    private func processContrastModifier(_ node: FunctionCallExprSyntax) {
        processNumericModifier(node, input: .contrast)
    }
    
    private func processCornerRadiusModifier(_ node: FunctionCallExprSyntax) {
        processNumericModifier(node, input: .cornerRadius)
    }
    
    private func processHueRotationModifier(_ node: FunctionCallExprSyntax) {
        if let angleArg = node.argumentList.first?.expression.trimmedDescription {
            // Extract angle value (e.g., "90.degrees" -> 90)
            let angleValue = angleArg.components(separatedBy: ".").first ?? "0"
            if let degrees = Double(angleValue) {
                let radians = degrees * .pi / 180
                let setHue = StepActionSetInput(
                    nodeId: currentNodeId,
                    port: .keyPath(.init(
                        layerInput: .hueRotation,
                        portType: .packed
                    )),
                    value: .number(radians),
                    valueType: .number
                )
                actions.append(setHue)
            }
        }
    }
    
    private func processSaturationModifier(_ node: FunctionCallExprSyntax) {
        processNumericModifier(node, input: .saturation)
    }
    
    // MARK: - Layout
    private func processPaddingModifier(_ node: FunctionCallExprSyntax) {
        if node.argumentList.isEmpty {
            // Default padding
            setPadding(edges: .all, length: 8) // Default padding
        } else if let lengthArg = node.argumentList.first?.expression {
            if let length = Double(lengthArg.trimmedDescription) {
                setPadding(edges: .all, length: length)
            }
        }
        // Handle edge-specific padding if needed
    }
    
    private func setPadding(edges: Edge.Set, length: Double) {
        let padding = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .padding,
                portType: .packed
            )),
            value: .number(length),
            valueType: .number
        )
        actions.append(padding)
    }
    
    private func processPositionModifier(_ node: FunctionCallExprSyntax) {
        guard node.arguments.count >= 2 else { return }
        let args = Array(node.arguments)
        let xArg = args[0].expression.trimmedDescription
        let yArg = args[1].expression.trimmedDescription
        
        if let x = Double(xArg), let y = Double(yArg) {
            // Set position
            let setPosition = StepActionSetInput(
                nodeId: currentNodeId,
                port: .keyPath(.init(
                    layerInput: .position,
                    portType: .packed
                )),
                value: .position(CGPoint(x: x, y: y)),
                valueType: .position
            )
            actions.append(setPosition)
        }
    }
    
    private func processScaleEffectModifier(_ node: FunctionCallExprSyntax) {
        if node.argumentList.count == 1 {
            let args = Array(node.argumentList)
            if let scale = Double(args[0].expression.trimmedDescription) {
                // Uniform scale
                let setScale = StepActionSetInput(
                    nodeId: currentNodeId,
                    port: .keyPath(.init(
                        layerInput: .scale,
                        portType: .packed
                    )),
                    value: .number(scale),
                    valueType: .number
                )
                actions.append(setScale)
            }
        }
        // Handle non-uniform scale if needed
    }
    
    private func processFrameModifier(_ node: FunctionCallExprSyntax) {
        var width: Double = 0
        var height: Double = 0
        var hasSize = false
        
        // Parse width and height from arguments
        for argument in node.argumentList {
            let label = argument.label?.text ?? ""
            let value = argument.expression.trimmedDescription
            
            if label == "width", let w = Double(value) {
                width = w
                hasSize = true
            } else if label == "height", let h = Double(value) {
                height = h
                hasSize = true
            } else if label == nil, let size = Double(value) {
                // Handle case like .frame(100) which sets both dimensions
                width = size
                height = size
                hasSize = true
            }
        }
        
        // Only set size if we have valid dimensions
        if hasSize {
            let setSize = StepActionSetInput(
                nodeId: currentNodeId,
                port: .keyPath(.init(
                    layerInput: .size,
                    portType: .packed
                )),
                value: .size(.init(width: width, height: height)),
                valueType: .size
            )
            actions.append(setSize)
        }
    }
    
    private func processZIndexModifier(_ node: FunctionCallExprSyntax) {
        guard let indexArg = node.argumentList.first?.expression.trimmedDescription,
              let index = Double(indexArg) else { return }
        
        let setZIndex = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: .zIndex,
                portType: .packed
            )),
            value: .number(index),
            valueType: .number
        )
        actions.append(setZIndex)
    }
    
    // MARK: - Helper
    private func processNumericModifier(_ node: FunctionCallExprSyntax,
                                        input: LayerInputPort) {
        guard let valueArg = node.argumentList.first?.expression.trimmedDescription,
              let value = Double(valueArg) else { return }
        
        let action = StepActionSetInput(
            nodeId: currentNodeId,
            port: .keyPath(.init(
                layerInput: input,
                portType: .packed
            )),
            value: .number(value),
            valueType: .number
        )
        actions.append(action)
    }
} // Close SwiftUIToStitchAIVisitor extension

// MARK: - Parser Function

func parseSwiftUICodeToActions(_ code: String) -> [any StepActionable] {
    print("\n=== Parsing SwiftUI Code ===")
    print("Source code:\n\(code)")
    
    let sourceFile = Parser.parse(source: code)
    print("\n=== Syntax Tree ===")
    print(sourceFile)
    
    let visitor = SwiftUIToStitchAIVisitor(viewMode: .sourceAccurate)
    visitor.walk(sourceFile)
    
    print("\n=== Found \(visitor.actions.count) actions ===")
    return visitor.actions
}

// MARK: - Example Usage

let nodeId = UUID() // Or use your system's node ID generator

// For Rectangle node
let addRectangle = StepActionAddNode(
    nodeId: nodeId,
    nodeName: .layer(.rectangle) // Correct PatchOrLayer enum with lowercase case name
)

let setFill = StepActionSetInput(
    nodeId: nodeId,
    port: .keyPath(.init(
        layerInput: .color, // Use correct enum case from LayerInputPort_V32
        portType: .packed
    )),
    value: .color(.blue), // Fully qualified PortValue.color case with Color.blue
    valueType: .color      // Fully qualified NodeType.color
)

let setOpacity = StepActionSetInput(
    nodeId: nodeId,
    port: .keyPath(.init(
        layerInput: .opacity, // Use correct enum case from LayerInputPort_V31
        portType: .packed
    )),
    value: .number(0.5), // Fully qualified PortValue.number case with Double value
    valueType: .number    // Fully qualified NodeType.number
)

let actions: [any StepActionable] = [addRectangle, setFill, setOpacity]

// Example usage of the parser
let test0Code = """
Rectangle.fill(Color.blue).opacity(0.5)
"""



let test1 = """
Text(“salut”)
"""

let test2 = """
VStack { 
  Text(“salut”)
}.padding(8)
"""

let test3 = """
VStack { 
  Text(“salut”).padding(16).border(.red)
}.padding(8)
"""

let test4 = """
HStack { 

    Image(systemName: “document”)

    VStack { 
        Text(“salut”).padding(16).border(.red)
        Rectangle().fill(.blue).frame(width: 200, height: 100)

    }.padding(8)

}
"""


