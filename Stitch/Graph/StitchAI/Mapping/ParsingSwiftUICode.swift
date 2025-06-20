import SwiftSyntax
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
    "Keyboard Type" : ".keyboardType",
    "Opacity" : ".opacity",
    "Padding" : ".padding",
    "Position" : ".position",
    "Saturation" : ".saturation",
    "Scale" : ".scaleEffect",
    "Size" : ".frame",
    "Text Decoration" : ".underline",
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
import Foundation

let nodeId = UUID() // Or use your system's node ID generator

// For Rectangle node
let addRectangle = StepActionAddNode(
    nodeId: nodeId,
    nodeName: .layer(.rectangle) // Correct PatchOrLayer enum with lowercase case name
)

// For Color input - using keyPath for named port
let colorPort = Step_V0.NodeIOPortType.keyPath(.init(
    layerInput: LayerInputPort_V31.LayerInputPort.color, // Use correct enum case from LayerInputPort_V31
    portType: .packed
))

let setFill = StepActionSetInput(
    nodeId: nodeId,
    port: colorPort,
    value: .color(.blue), // Fully qualified PortValue.color case with Color.blue
    valueType: .color      // Fully qualified NodeType.color
)

// For Opacity input - using keyPath for named port
let opacityPort = Step_V0.NodeIOPortType.keyPath(.init(
    layerInput: LayerInputPort_V31.LayerInputPort.opacity, // Use correct enum case from LayerInputPort_V31
    portType: .packed
))

let setOpacity = StepActionSetInput(
    nodeId: nodeId,
    port: opacityPort,
    value: .number(0.5), // Fully qualified PortValue.number case with Double value
    valueType: .number    // Fully qualified NodeType.number
)

let actions: [any StepActionable] = [addRectangle, setFill, setOpacity]







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

