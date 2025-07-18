//
//  AIGraphBuilderSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/18/25.
//

import SwiftUI

extension StitchAIManager {
    @MainActor
    func stitchAIGraphBuilderSystem(graph: GraphState) throws -> String {
        let codeBuilderPrompt = try Self.aiCodeGenSystemPromptGenerator()
        let patchBuilderPrompt = try Self.aiPatchBuilderSystemPromptGenerator()
        
        let patchDescriptions = AIGraphData_V0.Patch.allAiDescriptions
            .filter { description in
                !description.nodeKind.contains("scrollInteraction") &&
                !description.nodeKind.contains("legacyScrollInteraction")
            }
        
        let layerDescriptions = AIGraphData_V0.Layer.allAiDescriptions
        
        let nodePortDescriptions = try NodeSection.getAllAIDescriptions(graph: graph)
        
        return """
# Code Generation and Graph Builder for Stitch

You are a tool that creates data for prototypes in our app, called Stitch. Stitch uses a visual programming language and is similar to Meta's Origami Studio. Like Origami, Stitch contains “patches”, which is the set of functions which power the logic to an app, and “layers”, which represent the visual elements of an app.

The end-goal is to produce structured data that modifies an existing document. To get there, we will first convert existing graph data into SwiftUI code, make modifications to that SwiftUI code based on user prompt, and then convert that data back into Stitch graph data.

You will call a series of OpenAI functions in sequential order. The job of these functions is to break down graph building into scoped steps. These functions are:
1. **`\(StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeBuilder.rawValue)`: build SwiftUI Code from Stitch Data.** You will receive as input structured data about the current Stitch document, and your output must be a SwiftUI app that reflects this prototype.
2. **`\(StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.codeEditor.rawValue)`: edit SwiftUI Code.** Based on the SwiftUI source code created from the last step, modify the code based on the user prompt.
3. **`\(StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions.patchBuilder.rawValue)`: create Stitch structured prototype data.** Convert the SwiftUI source code into Stitch concepts. 

# SwiftUI Code Builder Function
\(codeBuilderPrompt)

# SwiftUI Code Editor Function
Modify SwiftUI source code based on the request from a user prompt. Use code returned from the last function caller. Adhere to previously defined rules regarding patch and layer behavior in Stitch.

Default to non-destructive functionality--don't remove or edit code unless explicitly requested or required by the user's request.

# Stitch Code Conversion Function
\(patchBuilderPrompt)

# Stitch Data Glossary

Each function is adhering to a specific set of rules which are designed to restrict the known universe to Stitch-only concepts. Invoked functions should consult this glossary whenever Stitch-specific data is created.

## `PortValue` Example Payloads

Example payloads for each `PortValue` by its type are provided below. Strictly adhere to the schemas in these examples.

```
\(try StitchAISchemaMeta.createSchema().encodeToPrintableString())
```

## Native Stitch Patches
Each function should mimic logic composed in patch nodes in Stitch (or Origami Studio). We provide an example list of patches to demonstrate the kind of functions expected in the Swift source code:

```
\(try patchDescriptions.encodeToPrintableString())
```

## Layer Types
You may expect the following layer types:

```
\(try layerDescriptions.encodeToPrintableString())
```

### Inputs and Outputs Definitions for Patches and Layers

The schema below presents the list of inputs and outputs supported for each native patch and layer in Stitch. Patches here cannot be invoked unless previously stated as permissible earlier in this document. Layers themselves cannot be created here, however we can set inputs to layers that are passed into the `updateLayerInputs` function. 

**Please note the value types for `label` used specifically for layer nodes below. This refers to the name of the layer port that is used for `LayerPortCoordinate`**. 

For layers, if the desired behavior is natively supported through a layer’s input, the patch system must prefer setting that input over simulating the behavior with patch nodes.

Each patch and layer supports the following inputs and outputs:
```
\(try nodePortDescriptions.encodeToPrintableString())
```

"""
    }
}
