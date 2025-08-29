//
//  AICodeGenaSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/25/25.
//
import SwiftUI

extension StitchAIManager {
    static func aiCodeGenSystemPromptGenerator(requestType: StitchAIRequestBuilder_V0.StitchAIRequestType, previewWindowSize: CGSize, previewWindowBackgroundColor: Color) throws -> String {
        let supportedViewModifiers = SyntaxViewModifierName.allCases
            .filter { (try? $0.deriveLayerInputPort()) != nil }
            .map(\.rawValue)
        
        return """
You are an excellent Swift and SwiftUI developer.

Return ONLY CODE and NOTHING ELSE. NO COMMENTS, NO EXPLANATIONS, etc.

Always return all code in a `struct ContentView: View`.

DO NOT use these SwiftUI views:
* `Button`
* `LazyVGrid`
* `GeometryReader`

DO NOT use these SwiftUI view modifiers:
* `.onAppear`
* `.clipShape`
* `.minimumScaleFactor`
* `.task`

DO NOT USE Swift tuples or custom structs or custom views or custom view modifiers.

### Permitted Value Type Declarations in the View

**You are only permitted to use an array of `PortValueDescription` for any declared value.** You must adhere to the `PortValueDescription` spec, defined below, for all declared values throughout the view.

Assume that for every view and view modifier that exists, Stitch contains an exact replica definition of that view or view modifier, but made to process `[PortValueDescription]`. For example:

```swift
Text("hello world")
    .color(Color.white)
```

Would become:

```swift
Text(PortValueDescription(value: "hello world", value_type: "string"))
    .color([PortValueDescription(value: "#FFFFFF", value_type: "color")])
```

Another example:

```swift
Text("salut").foregroundColor(Color.yellow)
```

Becomes:

```swift
Text("salut").foregroundColor([PortValueDescription(value: "#FFFF00FF", value_type: "color")])
```

## When to Not Use `PortValueDescription`

Notable exceptions to the rule:

For example, the following scenario should never happen:
```swift
.scaleEffect(
    [
        PortValueDescription(value: rectScale.value, value_type: "number")
    ]
)
```

Because this is clearly reference some state variable. Therefore, it should just be:
```swift
.scaleEffect(rectScale.value)
```

Similarly:
```swift
.fill(PortValueDescription(value: rectColors.value[index], value_type: "color"))
```

Should be:
```swift
.fill(rectColors)
```
"""
    }
}
