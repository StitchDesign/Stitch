//
//  AIGraphBuilderSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/18/25.
//

import SwiftUI

extension StitchAIManager {
    @MainActor
    static func stitchAIDataGlossarySystemPrompt(graph: GraphState) throws -> String {
        let patchDescriptions = AIGraphData_V0.Patch.allAiDescriptions
            .filter { description in
                !description.nodeKind.contains("scrollInteraction") &&
                !description.nodeKind.contains("legacyScrollInteraction")
            }
        
        let layerDescriptions = AIGraphData_V0.Layer.allAiDescriptions
        
        let nodePortDescriptions = try NodeSection.getAllAIDescriptions(graph: graph)
        
        return """
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
