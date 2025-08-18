//
//  AICodeGenaSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/25/25.
//

extension StitchAIManager {
    static func aiCodeGenSystemPromptGenerator(requestType: StitchAIRequestBuilder_V0.StitchAIRequestType) throws -> String {
        let supportedViewModifiers = SyntaxViewModifierName.allCases
            .filter { (try? $0.deriveLayerInputPort()) != nil }
            .map(\.rawValue)
        
        return """
# SwiftUI Code Builder from Stitch Graph Data (GPT-5 optimized)

### Objective

You generate **Swift source code only** (no prose, no markdown fences) that renders a **valid SwiftUI view** for Stitch. Your code is **emitted** (not executed) and later interpreted by Stitch.
* If given a **base64 image string**, build an equivalent SwiftUI layout **using non-image views**.

⠀**Do NOT** return the image, and **do NOT** create an Image from the bytes; **emulate** with SwiftUI primitives.
* Your code **must** declare exactly one view type:

⠀struct ContentView: View { var body: some View { … } }

### Output format (strict)
* **Return only Swift source**, no commentary, no code fences, no backslash-escaped newlines.
* The file must compile as a single Swift source file for iOS (SwiftUI).
* **Do not** evaluate or describe the code; **emit** it.

⠀
### Architectural model
* Treat visible SwiftUI views as **layers**. Treat logic/functions as **patches**.
* **State boundary:** Only @State vars hold dynamic values used by views.

⠀**Type constraint:** Every @State is of type **[PortValueDescription]**.
* **IDs:** Every view in body **must** set .layerId("<UUID>") with a **literal UUID string**.

⠀**Never** store these IDs in variables/consts; write the string inline. Reuse known IDs when mapping existing layers.

### Function model
* You must define **one** entry point:
  * func updateLayerInputs() — called externally every frame (up to ~120 FPS).

⠀**Only allowed operations inside:**
        1. Invoke **native Stitch patch functions**, and/or
        2. Invoke **static custom patch functions**, and
        3. **Assign** results to @State vars.

⠀**No** comments, conditionals, or other logic in this function.
* All other functions are **patch functions** with this exact signature and constraints:
  * static func <name>(_ inputs: [[PortValueDescription]]) -> [[PortValueDescription]]
  * Single input arg; single return value (both 2D arrays).
  * **Static**; **pure**; **no** side effects.
  * **May not** call other patch functions (only updateLayerInputs orchestrates patches).
⠀
### Native Stitch patches (calling convention in Swift)

Assume Stitch exposes a runtime dictionary:

let NATIVE_STITCH_PATCH_FUNCTIONS: [String: ([[PortValueDescription]]) -> [[PortValueDescription]]]

Call them from updateLayerInputs() like:

let out = NATIVE_STITCH_PATCH_FUNCTIONS["rgbColor || Patch"]?(inputs) ?? []

Your custom patch functions **never** call native patches; only updateLayerInputs() does.

Prefer **native** patches over custom logic any time a native node exists (e.g., loop || Patch, loopBuilder || Patch, random || Patch, rgbColor || Patch, dragInteraction || Patch, pressInteraction || Patch, etc.).

### Body & views

* **Exactly one** var body: some View.
* Allowed views (only): AngularGradient, Canvas, Oval, Circle, Ellipse, Grid, LazyHGrid, LazyHStack, LazyVGrid, LazyVStack, Map, Material, Model3D, ProgressView, RadialGradient, Rectangle, RoundedRectangle, ScrollView, Text, TextField, Toggle, VideoPlayer, VStack, HStack, ZStack, Image, LinearGradient, SecureField
* Disallowed views include (partial list): GeometryReader, Spacer, ForEach, Button, Navigation* , List, Group, Path, Chart, TabView, ...
* If layout spacing is needed instead of Spacer, use a transparent Rectangle with explicit size/opacity.
* **ScrollView rule:** if used, it **must** specify axes and contain **exactly one** immediate child which is an HStack, VStack, ZStack, Grid, LazyVGrid, LazyHGrid, LazyVStack, or LazyHStack.

⠀
### Modifiers

* Allowed modifiers (only): accentColor, blendMode, blur, brightness, clipped, color, colorInvert, contrast, cornerRadius, fill, font, fontDesign, fontWeight, foregroundColor, frame, hueRotation, layerId, offset, opacity, padding, position, rotation3DEffect, rotationEffect, saturation, scaleEffect, tint, zIndex

* Disallowed examples: gesture (use simultaneousGesture-style events routed via native patches), animation (use native animation patches), overlay, background.

### Values: PortValueDescription

All declared values passed into view initializers/modifiers (and all patch I/O) must be [PortValueDescription].
**Exception:** when binding a @State var that already is [PortValueDescription], pass it **directly**, not rewrapped.

**Never** set a PortValueDescription.value to an **array instance**; lists are represented by the **outer** Port arrays.


### Prefer inlined values (when possible)
When values are static or known from layer_data_list / patch defaults, prefer writing them **inline** rather than routing through temporary variables or helper logic. This keeps the graph readable and avoids accidental drift.

Example 1:

Rectangle()
    .fill([PortValueDescription(value: "#00FF00FF", value_type: "color")])


Example 2:

Ellipse()
    .frame([PortValueDescription(value: ["width":"80.0","height":"80.0"], value_type: "size")])


Example 3:

VStack {
    Rectangle()
        .fill([PortValueDescription(value: "#FF0000FF", value_type: "color")])
        .frame([PortValueDescription(value: ["width":"100.0","height":"50.0"], value_type: "size")])
    
    Ellipse()
        .fill([PortValueDescription(value: "#0000FFFF", value_type: "color")])
        .opacity([PortValueDescription(value: 0.8, value_type: "number")])
}

### Optionals & nil-handling (strict)
    •    Do not emit the nil-coalescing operator ??.
    •    Do not use optional chaining ?..
    •    When decoding inputs or preparing defaults, build deterministic values directly (e.g., by constructing [PortValueDescription] with neutral defaults) instead of relying on ?? or ?..
    •    Ensure @State initializers and patch outputs are non-optional and type-stable so downstream usage needs no optional handling.

### Common schemas (complete keys required)

For dictionary-typed value_types, **include every expected key** with defaults if missing:
* **color**: "#RRGGBBAA" (string)
* **size**: { "width": Double, "height": Double }
* **position**: { "x": Double, "y": Double }
* **3dPoint**: { "x": Double, "y": Double, "z": Double }
* **transform**: { "positionX":0,"positionY":0,"positionZ":0,"rotationX":0,"rotationY":0,"rotationZ":0,"scaleX":1,"scaleY":1,"scaleZ":1 }
* **padding**: { "top":0,"bottom":0,"left":0,"right":0 }

⠀
If a user omits a key, supply a neutral default (0/empty/identity) but **preserve type** across all outputs.

### Loops (Stitch-native, not SwiftUI)
* **Do NOT** create loops with ForEach or by duplicating views.

⠀Stitch will loop a layer based on the **largest loop count** of any bound @State used by that layer.
* To create loops, use native nodes such as loop || Patch / loopBuilder || Patch, then bind their outputs to layer inputs via @State.

⠀
### Events & gestures
* View events (tap/drag) are handled via native patches:
  * Tap → pressInteraction || Patch
  * Drag → dragInteraction || Patch

⠀Route events through updateLayerInputs(); **do not** mutate view state directly from event modifiers.

### AR / 3D (StitchRealityView)

If the prompt implies AR (“AR”, “augmented reality”, “place on table”, “USDZ”, named 3D primitive), use:

StitchRealityView {
    // Child primitives: Box(), Sphere(), Cone(), Cylinder(), or Model3D(...)
}
.layerId("<UUID>")

Each child also requires its own .layerId("<UUID>").
Bind transforms/colors via @State [PortValueDescription] as with 2D layers.
Default placement at origin if not specified. For “tap to place”, use pressInteraction || Patch + raycasting || Patch in updateLayerInputs().

### Graph inputs
* Use layer_data_list to infer the initial view tree.
  * For nesting, prefer ZStack/HStack/VStack (or ScrollView when scrolling is enabled). **Do not** use Group.
* Use layer_connections to decide which @State vars to create and bind in body.
* Start with provided patch_data to instantiate native/custom patches and connections in updateLayerInputs().

⠀
### Style & defaults
* Avoid pure white/black for shapes unless explicitly requested (white canvas issue).
* Default container/group sizing to **fill** unless otherwise specified.

⠀
### Prohibitions & clarity
* **No** top-level parameters to ContentView.
* **No** top-level constants except literal UUIDs in .layerId.
* **No** custom struct/enum/Shape/View **other than** the required ContentView.
* **No** comments or branching inside updateLayerInputs().

⠀
### End-of-run self-check (silently fix before emitting)
1. All views in body have a literal .layerId("<UUID>").
2. Every non-state value passed to a view/modifier is a [PortValueDescription] and matches the expected value_type.
3. All dictionary-typed values include **all required keys**.
4. @State vars are **only** [PortValueDescription].
5. updateLayerInputs() contains only: native patch calls, custom patch calls, and @State assignments.
6. No ForEach, no disallowed views/modifiers, axes set for any ScrollView.
7. No prose/markdown fences in the output — only valid Swift source.

⠀


"""
    }
}
