# Stitch Nodes

## 3D Model

The 3D Model Layer will display a 3D model asset (of a USDZ file type) in the preview window.

*Inputs*

* 3D Model Asset
* 3D Anchor Entity
* Animation
* 3D Transform (Translation/Scale/Rotation)
* Translation Gesture
* Scale Gesture
* Rotation Gesture
* Position (X/Y)
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index

## AR Anchor

Creates an AR anchor from a 3D model and an ARTransform. Represents the position and orientation of a 3D item in the physical environment.

*Inputs*

* A 3D model that will be displayed in the AR scene
* The ARTransform that's received from a Raycasting node.

*Outputs*

* The AR anchor value; which is used as an input for the RealityView node.

## Absolute Value

This node takes an input, converts it to a number, and returns the absolute value of that number.

*Inputs*

* Number, or something that will be converted to a number.

*Outputs*

* Absolute value of the input.

## Add

The add node takes two or more inputs, and returns the sum of those values. If they're numbers, they'll be added together. If they're strings, they'll be concatenated. If they're arrays, they'll be concatenated. If they're objects, they'll be merged. Etc.

*Inputs*

* At least two values that should be merged.

*Outputs*

* Sum of the inputs.

## And

And is a boolean operator that returns true if both inputs are true.

*Inputs*

* One or more values that should be compared.

*Outputs*

* One boolean value that is true if all inputs are true.

## Angular Gradient

Creates an angular gradient.

*Inputs*

* Center anchor
* Start color
* End color

## Any

Any is a boolean node that returns true if any of the inputs are true.

*Inputs*

* Any set of values that will be compared.

*Outputs*

* One boolean value that is true if any of the inputs are true.

## Arc Tan 2

ArcTan2 is a node that takes two inputs, and returns the arctangent of the first input divided by the second input.

*Inputs*
Two inputs, the arctangent of the first, which will be divided by the second.

*Outputs*

* The arctangent of the first input divided by the second input.

## Array Append

This node appends to the end of the provided array.

*Inputs*

* The array to append to.
* The value to append to the array.

*Outputs*

* The array with the value appended to the end.

## Array Count

This node returns the number of items in an array.

*Inputs*

* The array to count the items of.

*Outputs*

* The number of items in the array.

## Array Join

This node joins one or more arrays together into a single array.

*Inputs*

* The set of arrays to join together.

*Outputs*

* The joined array.

## Array Reverse

This node reverses the order of the items in the array.

*Inputs*

* The array to reverse.

*Outputs*

* The reversed array.

## Array Sort

This node sorts the array in ascending order.

*Inputs*

* The array to sort

*Outputs*

* The sorted array

## Base64 To Image

A node that converts a Base64 string to an image asset.

*Inputs*

* A Base64 string

*Outputs*

* An image asset

## Bouncy Converter

Node for converting Pop Animation values to spring tension and friction.

*Inputs*

* Bounciness
* Speed

*Outputs*

* Friction
* Tension

## Box

A box 3D shape, which can be used inside a Reality View.

*Inputs*

* 3D Anchor Entity
* 3D Size (Width/Height/Depth)
* 3D Transform (Translation/Scale/Rotation)
* Translation Gesture
* Scale Gesture
* Rotation Gesture
* Position (X/Y)
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Corner Radius
* Color
* Metallic

## Camera Feed

Creates a video feed from a hardware camera.

*Inputs*

* A boolean to enable/disable the camera feed
* A selector for which camera to use
* A selector for the orientation to display the camera feed in

*Outputs*

* The video feed frames
* The size of the video feed

## Canvas Sketch

Draw custom shapes by interacting with the prototype window.

*Inputs*

* Line Color
* Line Width
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (Width / Height)
* Opacity
* Scale
* Anchoring
* Z Index

*Outputs*

* Image

## Circle Shape

Generates a Circle shape from a given position and radius.

*Inputs*

* The X/Y location where the circle should be placed
* The radius of the circle

*Outputs*

* The generated Circle shape

## Classic Animation

Animates a number using a standard animation curve.

*Inputs*

* The Duration of the animation in Seconds
* The animation curve type

  * Linear
  * Quadratic - In
  * Quadratic - Out
  * Quadratic In / Out
  * Sinusoidal In
  * Sinusoidal In / Out
  * Exponential In
  * Exponential In / Out

*Outputs*

* The current value of the animation

## Clip

Clips a number to be within a specified set of bounds.

For example, if the input value is 10, the min is -5, and the max is 5, the output value will be 5.

*Inputs*

* Number to clip
* Lowest number to allow
* Highest number to allow

*Outputs*

* The clipped value

## Close Path

A ClosePath ShapeCommand.

*Inputs*

* None

*Outputs*

* None

## Color Fill

A layer for filling the preview window with a specified color.

*Inputs*

* A Bool for enabling/disabling the fill
* A color picker
* Opacity
* Z Index

## Color To Hex

Converts a provided color into a corresponding Hex string.

*Inputs*

* A color value

*Outputs*

* Hex string

## Color to HSL

Converts a provided color into its constituent HSL (Hue/Saturation/Light) components.

*Inputs*

* A color value

*Outputs*

* Hue
* Saturation
* Lightness
* Alpha

## Color to RGB

Converts a provided color into its constituent RGB (Red/Green/Blue) components (from 0 - 1).

*Inputs*

* A color value

*Outputs*

* Red
* Green
* Blue
* Alpha

## Commands to Shape

Generates a shape from a loop of given shape commands.

*Inputs*

* A loop of commands to generate a shape

*Outputs*

* A generated shape

## Cone

A cone 3D shape, which can be used inside a Reality View.

*Inputs*

* 3D Anchor Entity
* 3D Transform (Translation/Scale/Rotation)
* Translation Gesture
* Scale Gesture
* Rotation Gesture
* Position (X/Y)
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Color
* Metallic
