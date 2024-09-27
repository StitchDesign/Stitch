// MARK: Animations

let canvasSketchDescription = """
Draw custom shapes by interacting with the prototype window.

*Inputs*
• Line Color
• Line Width
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (Width / Height)
• Opacity
• Scale
• Anchoring
• Z Index

*Outputs*
• Image
"""

let bouncyConverterDescription = """
Node for converting Pop Animation values to spring tension and friction

*Inputs*
• Bounciness
• Speed

*Outputs*
• Friction
• Tension
"""

let classicAnimationDescription = """
Animates a number using a standard animation curve.

*Inputs*
• The Duration of the animation in Seconds
• The animation curve type
    • Linear
    • Quadratic - In
    • Quadratic - Out
    • Quadratic In / Out
    • Sinusoidal In
    • Sinusodial In / Out
    • Exponential In
    • Exponential In / Out


*Outputs*
• The current value of the animation
"""

let cubicBezierAnimationDescription = """
Creates custom animation curves by defining two control points

*Inputs*
• The number to animate to
• Duration fo the animation
• X position of first control point
• Y position of first control point
• X position of second control point
• Y position of second control point


*Outputs*
• The current value of the animation
• The X/Y value of the input progress
"""

let cubicBezierCurveDescription = """
Generates custom cubic bezier animation curves by specifying 2 control points.

*Inputs*
• 0-1 number representing the animation progress
• X positon of the first control point
• Y position of the first control point
• X position of the second control point
• Y posiiton of the second control point

*Outputs*
• Progress value derived from the cubic bezier curve
• X/Y position of the input progress on the curve
"""

let curveDescription = """
Changes the rate of a linear animation to follow a new animation curve.

*Inputs*
• Progress (0-1 value that represents the progress of an animation)
• The type of curve
    • Linear
    • Quadratic - In
    • Quadratic - Out
    • Quadratic In / Out
    • Sinusoidal In
    • Sinusodial In / Out
    • Exponential In
    • Exponential In / Out

*Outputs*
• The progress value of the curve
"""

let popAnimationDescription = """
Animates a value using a spring effect.

*Inputs*
• The number to animate too
• Bounciness of the animation
• Speed of the animation

*Outputs*
• The current value of the animation
"""

let springAnimationDescription = """
Creates an animation based off of the physical model of a spring.

*Inputs*
• The number to animate to
• The mass of the object that's being animated
• The ammount of tension in the spring
• How much friction is applied to the spring

*Outputs*
• The current value of the animation
"""

let repeatingAnimationDescription = """
Repeatedly animates a number.

*Inputs*
• A Boolean to enable/disable the animation
• Duration
• The type of curve
    • Linear
    • Quadratic - In
    • Quadratic - Out
    • Quadratic In / Out
    • Sinusoidal In
    • Sinusodial In / Out
    • Exponential In
    • Exponential In / Out
• Mirrored - a Boolean that will make hte animation go back and forth between 0 and 1 if True. If False, it will immediately go back to 0 when the animation reaches 1
• Rest pulse - resets the progress output back to 0

*Outputs*
• Progress value of the animation
"""

let smoothValueDescription = """
Smooths a given input value based on a hysteresis value. Hysteresis is a number between 0 and 1 that represents the rate at which the value will be smoothed over time.

The formula for calculating the smoothed value is:

    smoothedValue = (previousValue • hysteresis) + (currentValue • (1 - hysteresis))

This method is particularly useful for filtering noisy or fluctuating data streams, like sensor readings or user input, to obtain more stable and reliable values.

*Inputs*
• `numberToSmooth`: The current value that needs to be smoothed. This could be a sensor reading, user input, or any other fluctuating numerical data.
• `hysteresis`: A number between 0 and 1 that sets the smoothing rate. A value closer to 1 will result in slower changes and more smoothing, while a value closer to 0 will be more responsive to changes in the input.
• `resetPulse`: A signal or event to reset the smoothed value to its original state. This could be useful in scenarios where you want to clear history and start fresh.

*Outputs*
• `smoothedValue`: The smoothed value computed using the hysteresis formula. This value takes into account the previous smoothed value and the current input, weighted by the hysteresis factor.

"""

let transitionDescription = """
Transform a numerical value in the range of 0 to 1 (commonly used to represent progress) to another numerical value within a different specified range, defined by its start and end points.

For example, if the start value is 50 and the end value is 100:

• A progress of 0 will output 50
• A progress of .5 will output 75
• A progress of 1 will output 100

Values can be Color, Number, 3D Point, and Position.

*Inputs*
• The Progress value
• Start value
• End value

*Outputs*
• The converted value
"""

// MARK: Arrays

let valueAtIndexDescription = """
Given an array, this returns the value at a specific index in the array.

*Inputs*
• An array
• The index of the array that has the value you'd like to retrieve

*Outputs*
• The value in the array at the specified index
"""

let arrayAppendDescription = """
This node appends to the end of the provided array.

*Inputs*
• The array to append to.
• The value to append to the array.

*Outputs*
•  The array with the value appended to the end.
"""

let arrayCountDescription = """
This node returns the number of items in an array.

*Inputs*
• The array to count the items of.

*Outputs*
• The number of items in the array.
"""

let arrayJoinDescription = """
This node join's one or more arrays together into a single array.

*Inputs*
• The set of arrays to join together.

*Outputs*
• The joined array.
"""

let arrayReverseDescription = """
This node reverses the order of the items in the array.

*Inputs*
• The array to reverse.

*Outputs*
• The reversed array.
"""

let arraySortDescription = """
This node sorts the array in ascending order.

*Inputs*
• The array to sort

*Outputs*
• The sorted array
"""

let indexOfDescription = """
Returns the index of a given item in an array if the item is present

*Inputs*
• An array
• The item that you want to retrieve the index value of


*Outputs*
• The index at which the item occurs
• A Boolean indicating whether the array contains the given item.
"""

let subarrayDescription = """
Returns a subarray from a given array

*Inputs*
• An array
• The location to begin the subarray at
• The length of the subarray

*Outputs*
• The subarray
"""

// MARK: Audio

let microphoneDescription = """
A node for accessing the device microphone

*Inputs*
• A boolean to toggle the microphone on or off

*Outputs*
• The current volume of the microphone input
• The peak volume of the microphone
"""

let speakerDescription = """
A node for playing audio through the device speaker

*Inputs*
• An audio file
• The volume of the playing audio
"""

let soundKitDescription = """
NOT USED
"""

// MARK: Augmented Reality

let arAnchorDescription = """
Creates an AR anchor from a 3D model and an ARTransform. Represents the position and orientation of a 3D item in the physical environment.

*Inputs*
• A 3D model that will be displayed in the AR scene
• The ARTransform that's received from a Raycasting node.

*Outputs*
• The AR anchor value; which is used as an input for the RealityView node.
"""

let arRaycastingDescription = """
Returns a 3D location in physical space that corresponds to a given 2D location on the screen.

*Inputs*
• A pulse the triggers a raycast query when fired
• A Boolean to toggle raycasting On and Off
• Origin (specifies what type of plane detection to use in the raycasting operation)
    • Any
    • Horizontal
    • Vertical

*Outputs*
• ARTransform, which is used as an input for the AR Anchor node
"""

// MARK: Boolean Operations

let anyDescription = """
Any is a boolean node that returns true if any of the inputs are true.

*Inputs*
• Any set of values that will be compared.

*Outputs*
• One boolean value that is true if any of the inputs are true.
"""

let orDescription = """
Calcluats an OR Boolean operation. If at least one input is true, the output will be true. For example, if both inputs are 0, the output will be false. If one input is 0 and another is 1, the output will be true.

*Inputs*
• At least two inputs. N number of inputs can be added to the node.

*Outputs*
• A Boolean that retuns true if at least one of the inputs are true
"""

let andDescription = """
And is a boolean operator that returns true if both inputs are true.

*Inputs*
• One or more values that should be compared.

*Outputs*
• One boolean value that is true if all inputs are true.
"""

let notDescription = """
Performs a NOT Boolean operation where the input is inverted. For example, if the input is 0, the output is 1. If the input is 0, the output is 0.

*Inputs*
• A single input

*Outputs*
• A Boolean output that returns the opposite of whatever the input is
"""

// MARK: Colors

let colorToHexDescription = """
Converts a provided color into a corresonding Hex string.

*Inputs*
• A color value

*Outputs*
• Hex string
"""

let colorToHSLDescription = """
Converts a provided color into its constituent HSL (Hue/Saturation/Light) components.

*Inputs*
• A color value

*Outputs*
• Hue
• Saturation
• Lightness
• Alpha
"""

let colorToRGBDescription = """
Converts a provided color into its constituent RGB (Red/Green/Blue) components (from 0 - 1).

*Inputs*
• A color value

*Outputs*
• Red
• Green
• Blue
• Alpha
"""

let hexColorDescription = """
A node for converting a Hex String value to a color output.

*Inputs*
• Hex string

*Outputs*
• Color output
"""

let hslColorDescription = """
A node for generating a color from HSL (Hue/Saturation/Light) input values.

*Inputs*
• Hue
• Saturation
• Light
• Alpha

*Outputs*
• A color value
"""

let rgbaDescription = """
Creates a Color out of specified RGBA (Red/Green/Blue/Alpha) values (from 0 -1).

*Inputs*

• Red
• Green
• Blue
• Alpha

*Outputs*
• A color value
"""

// MARK: Gesture Interactions

let dragInteractionDescription = """
Makes a given layer responsive to drag interactions.

*Inputs*
• The Layer to add the Drag Interaction to
• A Bool to enable/disable the interaction
• A Bool to add momentum to the drag interaction
• Start Position (X/Y)
• A pulse that resets the inputs
• A Bool to Clip the interaction to a Min/Max position
• Min Position (X/Y)
• Max Position (X/Y)


*Outputs*
• Position (X/Y)
• Velocity (Width / Height)
• Translation (Width / Height)
"""

let pressInteractionDescription = """
Makes a given layer responsive to press interactions

*Inputs*
• The Layer to add the Press Interaction to
• A Bool to enable/disable the interaction
• Delay

*Outputs*
• A Boolean indicating if a Down event occured
• A pulse that's fired when a Tapped event occurs
• A pulse that's fired when a Double Tapped event occurs
• Position (X/Y)
• Velocity (Width / Height)
• Translation (Width / Height)
"""

let scrollInteractionDescription = """
Adds scroll interaction to a specified layer. Scrolling can be either free or paged (carousel).

*Inputs*
• The Layer to add the scroll interaction too
• Scroll X (Free / Paging / Disabled)
• Content Size (Width / Height)
• Direction Locking (Boolean)
• Page Size (Width / Height)
• Page Padding (Width / Height)
• Jump Style X
    • Instant
    • Animated
• Jump to X (Pulse)
• Jump Position X
• Jump Style Y
• Jump to Y
• Jump Position Y
• Decceleration Rate
    • Normal
    • Fast

*Outputs*
• The scroll X/Y position
"""

let mouseInteractionDescription = """
Makes a given layer responsive to mouse interactions

*Outputs*
• A Boolean indicating if a left click occurred
• A Boolean indicating if a right click occurred
• A Boolean indicating if a middle click occurred
• Position (X/Y)
• Scroll Velocity (Width / Height)
"""

// MARK: Image Operations

let imageToBase64StringDescription = """
A node that converts an image asset to a Base64 string.

*Inputs*
• An image asset

*Outputs*
• A Base64 string
"""

let base64StringToImageDescription = """
A node that converts a Base64 string to an image asset.

*Inputs*
• A Base64 string

*Outputs*
• An image asset
"""

let grayscaleDescription = """
Applies a grayscale filter to a provided visual media asset.

*Inputs*
• A media object; either an image or a video

*Outputs*
• The media object with a grayscale filter applied to it
"""

let qrCodeDetectionDescription = """
Detects a QR code in a video or image..

*Inputs*
• A media object; either an image or a video

*Outputs*
• A boolean indiciating if a QR code was detected
• Detected message in the QR code
"""

// MARK: JSON

let valueForKeyDescription = """
Given a JSON object and a key, extract the value from the JSON object

*Inputs*
• A JSON Object
• The key of the JSON object associated with the value you'd like to retrieve

*Outputs*
• The value at the specified key
"""

let setValueForKeyDescription = """
Allows you to set a value at a specified key in the JSON object.

*Inputs*
• A JSON object
• The key in the JSON object that you would like to set a new value to
• The new value

*Outputs*
• The JSON object with the new value.
"""

let jsonObjectDescription = """
Creates a JSON object out of an input key and value. The node can be configured to accept a variety of input value types.

*Inputs*
• The key
• The value you wnat to set corresponding to the key

*Outputs*
• The created JSON object
"""

let jsonArrayDescription = """
Creates a JSON array from a given list of inputs. N number of inputs can be added to the node.

*Inputs*
• The inputs to be added to the array

*Outputs*
• The JSON array of values
"""

let getKeysDescription = """
Returns the keys of a given JSON object. Useful for seeing what the output of a JSON object is that was received from a Network Request node.

*Inputs*
• A JSON Object

*Outputs*
• The keys of the JSON object in an array
"""

let valueAtPathDescription = """
Provides ways to access specific elements within a JSON object:

# Numbers for Array Indices
Use a number to specify an array index.
Example: `songs.0` will select the first song in an array of songs.

# Text Strings for Keys
Use a text string to pick a value by its key.
Example: `songs.0.artist` will select the artist of the first song in an array of songs.

# Asterisks for Child Arrays
An asterisk (•) targets all items within an array.
Example: `songs.•.artist` will select an array of artists for all songs.

# Double Dots for Recursive Search
Start with two dots (..) to perform a recursive search through the JSON object.
Example: `..artist` will find all instances of the key 'artist', regardless of nesting level.

*Inputs*
• A JSON Object
• The path to the value you want to retrieve; a text value written in dot notation.

*Outputs*
• The value that exists at the given path
"""

// MARK: Layers

let colorFillDescription = """
A layer for filling the preview window with a specified color.

*Inputs*
• A Bool for enabling/disabling the fill
• A color picker
• Opacity
• Z Index
"""

let convertPositionDescription = """
Converts position values between different parent layers.

*Inputs*
• From Parent (the Layer to get position of)
• From Anchor
• Point X/Y
• To Parent (the Layer to the converted position in)
• To Anchor

*Outputs*
• The converted X/Y position
"""

let hitAreaDescription = """
Adds interaction to a specific rectangle in the Preview Window.

*Inputs*
• A Boolean to Enable/Disable the Hit Area
• Position (X/Y)
• Size (Width / Height)
• Anchor
• Z Index
• A Boolean to toggle Setup Mode (visualizes the hit area)
"""

let imageDescription = """
The Image node is a Layer that will display an image asset in the Preview Window.

*Inputs*
• An image asset
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Fill Style
• Scale
• Anchoring
• Z-Index
• Clipped (Boolean)
"""

let groupDescription = """
"""

let layerInfoDescription = """
Returns information about a specified layer.

*Inputs*
• The layer to get info about.

*Outputs*
• A Boolean indicating if the layer is enabled
• Position
• Size
• Scale
• Anchor
• The layer's parent, if any
"""

let linearGradientDescription = """
Creates a linear gradient.

*Inputs*
• Start anchor
• End anchor
• First color
• Second color
"""

let radialGradientDescription = """
Creates a radial gradient.

*Inputs*
• Start anchor
• Start color
• End color
• Second color
"""

let angularGradientDescription = """
Creates an angular gradient.

*Inputs*
• Center anchor
• Start color
• End color
"""

let sfSymbolDescription = """
Creates an SF Symbol.
"""


let mapDescription = """
The Map node will display an Apple Maps UI in the preview window. 

*Inputs*
• Map Style
• Lattitude / Longitude
• Span
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Scale
• Anchoring
• Z-Index
• Stroke Position
• Stroke Width
• Stroke Color
"""

let model3DDescription = """
The 3D Model Layer will display a 3D model asset (of a USDZ file type) in the preivew window.

*Inputs*
• An 3D Model Asset
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Scale
• Anchoring
• Z-Index
"""

let ovalDescription = """
The Oval Layer will display an Oval shape in the Preivew Window.

*Inputs*
• Color
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Scale
• Anchoring
• Z-Index
• Stroke Position
• Stroke Width
• Stroke Color
"""

let progressIndicatorDescription = """
The Progress Indicator will display a Progress Indicator animation.

*Inputs*
• Animating
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Scale
• Anchoring
• Z-Index
• Stroke Position
• Stroke Width
• Stroke Color
"""

let realityViewDescription = """
The RealityView node will display the output of an Augmented Reality scene. It takes AR anchors (created with 3D models) as input.

*Inputs*
• An AR Anchor (see AR Anchor node)
• Camera Direction (Front / Back)
• Posiiton (X / Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (Width / Height)
• Opacity
• Scale
• Anchoring
• Z Index
• Camera Toggle
• Toggle for enabling/disabling shadows in the scene

"""

let rectangleDescription = """
The Rectnagle Layer will display a rectangle shape in the Preivew Window.

*Inputs*
• Color
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Scale
• Anchoring
• Z-Index
• Stroke Position
• Stroke Width
• Stroke Color
• Corner Radius
"""

let shapeDescription = """
The Shape Layer can take a shape as an input and display it in the preview window. The shape can be modified via a variety of inputs.

*Inputs*
• Shape
• Color
• Position (X/Y)
• Rotaiton X
• Rotation Y
• Rotation Z
• Size (Width/Height)
• Opacity
• Scale
• Anchoring
• Z Index
• Stroke Position (Inside or Outside)
• Stroke Width
• Stroke Color
• Coordinate System (Relative or Absolute)
"""

let splitterDescription = """
The value node is helpful for storing a value and sending that value to other nodes. You can also use these nodes in Groups to create an input port or an output port on the parent group. If you need to set a value and send that value to several other nodes, while having a single place to change that value, then this node is for you.

*Inputs*
• One port, that value you'd like to send to other nodes.

*Outputs*
• Again just a single port, that value you'd like to send to other nodes.
"""

let switchDescription = """
Displays an interactive UI toggle switch. 

*Inputs*
• Enabled
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Scale
• Anchoring
• Z-Index
• Stroke Position
• Stroke Width
"""

let textDescription = """
Displays a text value in the preview window.

*Inputs*
• Text value (a string)
• Color
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (Width / Height)
• Opacity
• Scale
• Anchoring
• Z Index
• Font Size
• Alignment
• Vertical Alignment
"""

let textFieldDescription = """
Enter text into the preview window.

*Inputs*
• Placeholder (a string)
• Color
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (Width / Height)
• Opacity
• Scale
• Anchoring
• Z Index
• Font Size
• Alignment
"""

let videoDescription = """
The Video Layer displays a video asset in the preview window.

*Inputs*
• A video asset
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Fill Style
• Scale
• Anchoring
• Z-Index
• Clipped (Boolean)
"""

let videoStreamingDescription = """
The Video Streaming Layer streams a video from a given URL string.

*Inputs*
• A URL to stream a video from
• Volume
• Position (X/Y)
• Rotation X
• Rotation Y
• Rotation Z
• Size (W/H)
• Opacity
• Fill Style
• Scale
• Anchoring
• Z-Index
• Clipped (Boolean)
"""

// MARK: Loops

let loopBuilderDescription = """
Create a loop out of any input type. N number of inputs can be added.

*Inputs*
• A 0th index value
• A 1st index value
• A 2nd index value

*Outputs*
• Loop of the indices of the input values
• Loop of the input values
"""

let loopCountDescription = """
Calculates the number of values in a loop.

*Inputs*
• An input loop

*Outputs*
• The number of outputs in a loop
"""

let loopDescription = """
Generate a loop of indices. For example, an input of 3 outputs a loop of [0, 1, 2].

*Inputs*
• Number representing the number of indices in the loop

*Outputs*
• Loop of indices
"""

let loopDedupeDescription = """
Removes duplicate values in a loop.

*Inputs*
• An input loop

*Outputs*
• The loop without duplicated values
• Loop of indices for the deduped loop
"""

let loopFilterDescription = """
A node that can filter out or repeat items in a loop. Two loops are passed in - the loop that you want to modify, and another loop that determines how many times each value should appear.

*Inputs*
• An input loop
• A loop of Booleans (to include or not), or loop of numbers (to set how many times a value is repeated)

*Outputs*
• The newly created loop with values either filtered or repeated
• Loop of indices
"""

let loopInsertDescription = """
Insert a new value at a particular index in a loop.

*Inputs*
• A loop to insert a new value into
• The value to insert into the loop
• The index at which the value should be inserted
• A pulse that will insert the value when triggered


*Outputs*
• The loop with the inserted value
• A loop of indices
"""

let loopOptionSwitchDescription = """
Returns the index of the last pulsed item in a loop of pulses

*Inputs*
• A loop of pulses

*Outputs*
• Index representing the last pulsed item in the loop
"""

let loopOverArrayDescription = """
Creates a loop over the items in a JSON array.

*Inputs*
• A JSON array

*Outputs*
• Loop of the indices for the input values
• Loop of values from the array
"""

let loopRemoveDescription = """
Removes a value from a specified index in a loop

*Inputs*
• An input loop
• The loop index at which you want to remove a value from
• A pulse that will remove the value when fired

*Outputs*
• The loop created after the value has been removed
• A loop of indices
"""

let loopReverseDescription = """
Reverse the order of the values in a loop

*Inputs*
• An input loop

*Outputs*
• The reversed loop
"""

let loopSelectDescription = """
Selects one or more values from a loop

*Inputs*
• A loop of values
• The index of the value to select. Multiple values can be selected by passing in a loop of indices

*Outputs*
• A loop made from the selected indice or indices
• The new index or set of indices
"""

let loopShuffleDescription = """
Randomly reorders the values in a loop.

*Inputs*
• A loop
• A pulse that triggers the reordering operation

*Outputs*
• A newly reordered loop
"""

let loopSumDescription = """
Calculates the sum of every value in a loop.

*Inputs*
• Loop to calculate the value of

*Outputs*
• The sum of the elements in the loop
"""

let loopToArrayDescription = """
Converts a loop to an array.

*Inputs*
• The loop to convert

*Outputs*
• A JSON array
"""

let runningTotalDescription = """
Calculates the sum of a loop of numbers - the sum at each index is the sum of the numbers preceding the current number.

*Inputs*
• An input loop

*Outputs*
• A loop of sums
"""

// MARK: Value Logic

let delayDescription = """
Delay a value by a specified number of seconds. The node can be configured to use a variety of value types.

*Inputs*
• The value to delay
• The ammount the value should be delayed
• Style: Trigger condition.
    -  Always: Applies delay regardless of value change.
    -  Increasing: Delays only when the value is rising.
    -  Decreasing: Delays only when the value is dropping.


*Outputs*
• The delayed value
"""

let delayOneDescription = DelayOneNode.description

let packDescription = """
Creates a value based on constituent inputs. For example, if you want to create a Size value, you would input two values corresponding to Width and Height.

Works with:
• Matrix Transform
• 3D Point
• 4D Point
• Position
• Shape Command
• Size

*Inputs*
• The individual values to create the final output

*Outputs*
• The constructed value based on the individual inputs
"""

let unpackDescription = """
Splits a value into constituent components. For example, an input value of type Size with a width of 20 and height of 40 woudl be split into individual values of 20 and 40.

Works with:
• Matrix Transform
• 3D Point
• 4D Point
• Position
• Shape Command
• Size

*Inputs*
• The value to unpack

*Outputs*
• The constituent values that make up the input
"""

let sizePackDescription = """
Packs two Layer Dimension inputs to a single Layer Size output.
"""

let sizeUnpackDescription = """
Unpacks a single Layer Size input to two Layer Size outputs.
"""

let positionPackDescription = """
Packs two Number inputs to a single Position output.
"""

let positionUnpackDescription = """
Unpacks a single Position input to two Number outputs.
"""

let point3DPackDescription = """
Packs three Number inputs to a single Point3D output.
"""

let point3DUnpackDescription = """
Unpacks a single Point3D input to three Number outputs.
"""

let point4DPackDescription = """
Packs four Number inputs to a single Point4D output.
"""

let point4DUnpackDescription = """
Unpacks a single Point4D input to four Number outputs.
"""

let transformPackDescription = """
Packs a Transform ouptut out of the following Number values:

• Position X
• Position Y
• Position Z
• Scale X
• Scale Y
• Scale Z
• Rotation X
• Rotation Y
• Rotation Z
"""

let transformUnpackDescription = """
Unpacks a Transform into the following constituent Number values:

• Position X
• Position Y
• Position Z
• Scale X
• Scale Y
• Scale Z
• Rotation X
• Rotation Y
• Rotation Z
"""

let closePathDescription = """
A ClosePath ShapeCommand.
"""

let moveToPackDescription = """
Packs a position input into a MoveTo ShapeCommand.
"""

let lineToPackDescription = """
Packs a position input into a LineTo ShapeCommand.
"""

let curveToPackDescription = """
Packs Point, CurveTo and CurveFrom position inputs into a CurveTo ShapeCommand.
"""

let curveToUnpackDescription = """
Unpack packs CurveTo ShapeCommand into a Point, CurveTo and CurveFrom position outputs.
"""

let counterDescription = """
Counter that can be incrimented, decrimented, or set to a specified value. Starts at 0.

*Inputs*
• Increase - pulse that increases the counter value
• Decrease - pulse that decreases the counter value
• Jump - pulse that resets the counter to the Jump to Number value
• Jump to Number - used as the counter value when the Jump port is pulsed
• Maximum Count - the counter will reset when this value is reached

*Outputs*
• The current value of the counter
"""

let flipSwitchDescription = """
A node that will flip between an On and Off state whenever a pulse is received.

*Inputs*
• A pulse that will flip the switch whenever a pulse is received
• A pulse to turn on the switch
• A pulse to turn off the switch

*Outputs*
• A Boolean On/Off Value
"""

let optionPickerDescription = """
The Option Picker node lets you cycle through and select one of N inputs to use as the ouptut. Multiple inputs can be added and removed from the node, and it can be configured to work with a variety of node types.

*Inputs*
• The index of the value you want to be selected
• N number of inputs

*Outputs*
• The selected value
"""

let optionSenderDescription = """
Used to pick an output to send a value to. Multiple value types can be used with this node.

*Inputs*
• Index of the value to send the output to
• Value to pass to selected outputs
• Default value to pass to unselected outputs


*Outputs*
• Option 0 - if selected, the value. Otherwise, the default.
• Option 1 - if selected, the value. Otherwise, the default.
"""

let timeDescription = """
Returns the number of seconds and frames that have passed since the prototype was started.

*Outputs*
• The number of seconds since the prototype started
• The number of frames since the prototype started
"""

let deviceTimeDescription = """
Returns the current time of the device your prototype is running on.

*Outputs*
• Device time in seconds
• Device time in milliseconds
"""

let locationDescription = """
The Location node returns the currently detected location value of the node.

*Inputs*
• An override of the detected location

*Outputs*
• The Lattitude of the location as a string
• The Longitude of the location as a string
• The city name as a string
"""

let randomDescription = """
Generates a random number between a specificed range

*Inputs*
• A pulse input that triggers the node
• The lower bound of the range at which a number can be generated
• The upper bound of the range at which a number can be generated

*Outputs*
• The generated random number
"""

let greaterOrEqualDescription = """
Checks if two input numbers are greater than or equal to one another

*Inputs*
• First value
• Second value

*Outputs*
• A boolean if the second value is greater than or equal to the first
"""

let lessThanOrEqualDescription = """
Checks if two input numbers are less than or equal to one another

*Inputs*
• First value
• Second value

*Outputs*
• A boolean if the second value is less than or equal to the first
"""

let equalsDescription = """
Checks if two numbers are equal, or if they are ~ equal to within a specified threshold.

*Inputs*
• First value
• Second value
• Threshold

*Outputs*
• A Bool that's true if the items are equal, and false if they are not
"""

let divideDescription = """
Node for calculating a Division operation

*Inputs*
• The Dividend (number you would like to divide)
• The Divisor (number by which the Dividend will be divided)


*Outputs*
• The result of the division operation
"""

let optionSwitchDescription = """
Used to control two or more states with an index value. N number of inputs can be added to the node.

*Inputs*
• A pulse that sets the Option Switch to 0
• A pulse that sets the Option Switch to 1
• A pulse that sets the Option Switch to 2

*Outputs*
• The index of the current state of the option switch
"""

let cameraFeedDescription = """
Creates a video feed from a hardware camera

*Inputs*
• A boolean to enable / disable the camera feed
• A selector for which camera to use
• A selector for the orientation to display the camera feed in

*Outputs*
• The video feed frames
• The size of the video feed

"""
// MARK: Machine Learning

let coreMLClassifyDescription = """
A node for classifiying an image via a CoreML Classificaiton model.

*Inputs*
• The CoreML model to use for classification. The default model is Resnet50.
• The image to classifiy; can be either an Image, a Video File, or a Camera Feed

*Outputs*
• The class that the model predicted the image is as a string
• The confidence value of the classification result
"""

let coreMLDetectionDescription = """
A node for detecting the objects in an image via a CoreML Object Detection model

*Inputs*
• The CoreML Object Detection to use for inference. YOLOv3 is the default model.
• The image to run inference on. Can be an image file, a video file, or the video input from a Camera Feed node.
• Crop & Scale mode. Options are
    • Center Crop
    • Scale to Fit (the default)
    • Scale to Fill
    • Scale to Fit 90°
    • Scale to Fill 90°


*Outputs*
• The detected objects in the image
• Confidence of the prediciton
• Locations of the detected objects
• Bounding Box of the detected objects
"""

// MARK: Math Operations

let absoluteValueDescription = """
This node takes an input, converts it to a number, and returns the absolute value of that number.

*Inputs*
• Number, or something that will be converted to a number.

*Outputs*
• Absolute value of the input.
"""

let addDescription = """
The add node takes two or more inputs, and returns the sum of those values. If they're numbers, they'll be added together. If they're strings, they'll be concatenated. If they're arrays, they'll be concatenated. If they're objects, they'll be merged. Etc.


*Inputs*
• At least two values that should be merged.

*Outputs*
• Sum of the inputs.
"""

let equalsExactlyDescription = """
Returns whether two input values are exactly equal to each other. It's the same thing as the "Equals" node, but, with a threshold set to 0.

*Inputs*
• Two values two compare against each other.

*Outputs*
• A Boolean indicating whether the input items are exactly equal.
"""

let greaterThanDescription = """
Checks whether a value is greater than another.

*Inputs*
• Two values to compare against each other.

*Outputs*
• A Boolean indicating if the first value is greater than the second value.
"""

let lessThanDescription = """
Checks whether a value is less than another.

*Inputs*
• Two values to compare against each other.

*Outputs*
• A Boolean indicating if the first value is less than the second value.
"""

let maxDescription = """
Given two inputs, returns the greater of the values.

*Inputs*
• Two inputs to compare

*Outputs*
• The maximum value
"""

let mathExpressionDescription = """
Evaluate a mathematical expression. Each variable in the expression becomes an input on the node.
"""

let minDescription = """
Given two inputs, returns the lesser of the values.

*Inputs*
• Two inputs to compare

*Outputs*
• The minimum value
"""

let modDescription = """
Calcuates the remainder when two input values are divided

*Inputs*
• The Base value to divide (the Numerator)
• The value to divide by (the denominator)

*Outputs*
• The Remainder
"""

let multiplyDescription = """
A node for multiplying two numbers.

*Inputs*
• The value to multiply
• The number at which to mulitple the value by

*Outputs*
• The result of the mulitplication
"""

let powerDescription = """
Calculates the the first (Base) value to the power of the second value (Exponent). The inputs can be a number, 3D point, position, or size.

*Inputs*
• The Base value
• The Exponent value

*Outputs*
• The value of the base to the exponent's power
"""

let progressDescription = """
Returns the ammount of progress completed by comparing the current value against the starting and ending values

*Inputs*
• A current value
• A starting value
• An ending value

*Outputs*
• The ammount of progress that has been completed
"""

let reverseProgressDescription = """
Returns the inverse ammount of progress completed by comparing the current value against the starting and ending values. The inverse of the Progreess node.

*Inputs*
• A current value
• A starting value
• An ending value

*Outputs*
• The ammount of progress that has been completed
"""

let roundDescription = """
Returns a rounded number.

*Inputs*
• The number to round
• The ammount of places to round the number to
• A Boolean indicating whether the number should be rounded up

*Outputs*
• The rounded number
"""

let squareRootDescription = """
Calculates the square root of an input the number

*Inputs*
• The number to calculate the square root of

*Outputs*
• The square root result
"""

let subtractDescription = """
Returns the result of the subtraction between two numbers.

*Inputs*
• The number to subtract
• The number to subtract by

*Outputs*
• The result of the subtraction
"""

// MARK: Media Import

let imageImportDescription = """
A node for importing an image asset into your prototype.

*Inputs*
• Selection for the image you would like to import

*Outputs*
• The image file
• The size of the image
"""

let model3DImportDescription = """
Enables importing and modifying USDZ 3D assets.

*Inputs*
• A selector for importing and selecting the 3D model
• If the model has baked-in animations, a boolean will toggle them on and off
• An AR Transform for adjusting the transform of the 3D model

*Outputs*
• The 3D model; can be connected to a 3D Model Layer for displaying in the Preview Window
"""

let soundImportDescription = """
A node for importing a sound file.

*Inputs*
• A selector for importing an audio file
• Jump time; the spot in the audio file you would like to jump to
• A pulse input to trigger the jump
• A boolean to toggle whether or not the audio is playing
• A boolean to toggle whether or not the audio is looping
• The playback rate of the audio file

*Outputs*
• The audio file; can be connected to a Speaker node to hear output
• Peak volume of the sound file
• Current playback position
• Duration of the sound file
• A loop of amplitude values for 16 component frequencies of the sound file
"""

let videoImportDescription = """
Allows for importing video file assets. The video can be displayed in the Preview Window by connecting this node to a Video Layer.

*Inputs*
• A selctor for importing a video file
• A boolean to set whether the video is scrubbalbe
• Number value to adjust the playback head of the video
• A boolean to play the video
• A boolean to loop the video

*Outputs*
• Average volume of the video
• Peak volume of the video
• Current playback position
• Duration of the video
"""

let sampleHoldDescription = """
Store and send a value until a new value is received, or the current value is reset.

*Inputs*
• The value to sample; can be configured to be any type
• A toggle to Enable/Disable sampling
• A pulse that will reset the input value

*Outputs*
• The currently sampled value
"""

let sampleRangeDescription = """
Use to create a loop out of a media input. When you've created your sample, the output of the node will be that sampled media. Can be used with video, audio, or other media or sensor data.

*Inputs*
• The media you want to sample
• A pulse to start sampling
• A pulse to end sampling

*Outputs*
• The sampled media
"""

// MARK: Network

let networkRequestDescription = """
The Network Request node allows you to make HTTP GET and POST requests to an endpoint. Results are returned as JSON.

*Inputs*
• The URL to make the request to
• URL parameters (as JSON)
• Request body (as JSON)
• Request headers (as JSON)
• Request method (GET or POST)
• A pulse input that initiates the URL request when triggered

*Outputs*
• Loading status (a Bool)
• Request result (as JSON)
• Error status (a Bool)
• Error (as JSON)
• Response headers (as JSON)
"""

// MARK: Pulses

let pulseDescription = """
Outputs a pulse event when it's toggled on or off.

*Inputs*
• A Boolean On/Off

*Outputs*
• A pulse if an "On" input event occurs
• A pulse if an "Off" output event occurs
"""

let pulseOnChangeDescription = """
The Pulse On Change node outputs a pulse if an input value comes in that is different from the specified value

*Inputs*
• A numerical value.

*Outputs*
• A pulse event that occurs if the value has changed
"""

let repeatingPulseDescription = """
A node that will fire a pulse at a defined interval

*Inputs*
• The frequency at which the pulse occrs

*Outputs*
• A pulse value
"""

// MARK: Prototype Actions

let whenPrototypeStartsDescription = """
A node that gets triggered whenever the prototype has started or restarted. Can be used to trigger any action you want to occur on the start.

*Outputs*
• A pulse that will be fired when the prototype start event occurs.
"""

let restartPrototypeDescription = """
A node that will restart the state of your prototype. All inputs and ouptuts of the nodes on your graph will be reset.

*Inputs*
• A pulse input serves as the single input for this node. When a pulse is received, the prototype will restart.
"""

let deviceInfoDescription = """
Returns spec information on the device that the prototype is running on.

*Outputs*
• Screen size
• Screen scale
• Orientation
• Device Type
• Appearence (Light or Dark mode)
"""

let velocityDescription = """
Measures the velocity, or rate of change, of an input value over time. The velocity is calculated by taking the difference between the current value and the previous value in consecutive frames or time intervals.

*Inputs*
• The value to measure

*Outputs*
• The velocity of the input
"""

let clipDescription = """
Clips a number to be within a specified set of bounds.

For example, if the input value is 10, the min is -5, and the max is 5, the output value will be 5.

*Inputs*
• Number to clip
• Lowest number to allow
• Highest number to allow

*Outputs*
• The clipped value
"""

let soulverDescription = """
The Soulver node enables evaluation of mathematical expressions. These can be done in plain English. For example, if you input a string of "10 percent of 100", your output will be 10.

*Inputs*
• An input query

*Outputs*
• The result of the Soulver operation
"""

let optionEqualsDescription = """
Checks if an input value (the "Option") is equal to any given inputs. The node can be configured to check a variety of input types. N number of inputs can be added.

*Inputs*
• Value that represents Option 1
• Value that represents Option 2

*Outputs*
• The option input that the value input is equal to
• A Boolean that indicates if the value input matches any of the option inputs
"""

let lengthDescription = """
Calcualtes the length of a given input. Can be a number, 3D point, position, size, or text.

*Inputs*
• Value to calculate the length of.

*Outputs*
• The length of the given value
"""

// MARK: Text

let splitTextDescription = """
Splits an input text string at a given token. For example, if the text value is "Stitch", and the token is "it", the output string will be "St"

*Inputs*
• The text to be split
• The token to split the input string at

*Outputs*
• The split text
"""

let textEndsWithDescription = """
Checks whether a provided text string contains a given suffix

*Inputs*
• A text string
• The suffix that you want to see if the text string contains

*Outputs*
• A Bool indicating whether or not the input text contains the suffix
"""

let textLengthDescription = """
Returns the length of a given text string.

*Inputs*
• Text (sring)

*Outputs*
• Length of the string
"""

let textReplaceDescription = """
A node for finding and replacing specified text in a given input text value

*Inputs*
• Given input text
• The string of text you would like to find
• The value that you would like to replace it with
• A Bool to select whether or not the Find/Replace operation should be case-sensitive or not

*Outputs*
• The modified text string
"""

let textStartsWithDescription = """
Checks whether an input text string contains a specified prefix

*Inputs*
• The input text
• The prefeix that the input text is checking to

*Outputs*
• A Bool indicating if the input text contains the given prefix
"""

let textTransformDescription = """
Transforms input text with different modifiers (Uppercase and Lowercase)

*Inputs*
• The text you want to transform
• The modifier to transform the text (Uppercase and Lowercase)

*Outputs*
• The transformed text
"""

let trimTextDescription = """
Trims provided text at specified start and end index points.

*Inputs*
• The text string to trim
• Starting index to start trimming at
• Ending index to finish trimming at

*Outputs*
• The trimmed text string
"""

let dateAndTimeFormatterDescription = """
Creates human readable date and time values from an input of time in seconds

*Inputs*
• The date or time represented in seconds
• Format
    • None (1970-01-01 00:00:00 +0000)
    • Short (12/31/69, 4:00 PM)
    • Medium (Dec 31, 1969 at 4:00:00 PM)
    • Long (December 31, 1969 at 4:00:00 PM PST)
    • Full (Wednesday, December 31, 1969 at 4:00:00 PM Pacific Standard Time)
• Custom format (a text string, for example: %H:%M:%S, %m/%d/%y)

*Outputs*
• Text string representing the formatted date and time value
"""

let stopwatchDescription = """
Measures elapsed time in seconds.

*Inputs*
• Pulse to start
• Pulse to stop
• Pulse to reset

*Outputs*
• Elapsed time in seconds
"""

// MARK: Trigonometry Operations

let arcTan2Description = """
ArcTan2 is a node that takes two inputs, and returns the arctangent of the first input divided by the second input.

*Inputs*
Two inputs, the arctangent of the first, which will be divided by the second.

*Outputs*
• The arctangent of the first input divided by the second input.
"""

let cosineDescription = """
Calculates the Cosine value of a given input angle.

*Inputs*
• The angle to calcuate the Sine value of

*Outputs*
• The Cosine value
"""

let sineDescription = """
Calculates the Sine value of a given input angle.

*Inputs*
• The angle to calcuate the Sine value of

*Outputs*
• The Sine value
"""

// MARK: Shapes

let circleShapeDescription = """
Generates a Circle shape from a given position and radius

*Inputs*
• The X/Y location where the circle should be placed
• The radius of the circle

*Outputs*
• The generated Circle shape
"""

let commandsToShapeDescription = """
Generates a shape from a loop of given shape commands

*Inputs*
• A loop of commands to generate a shape

*Outputs*
• A generated shape
"""

let jsonToShapeDescription = """
Generates a Shape from a given JSON object.

*Inputs*
• A JSON object
• The X and Y coordinate space values to place the shape in

*Outputs*
• The generated Shape
• An error, if one occured when trying to generate the shape
• The Width and Height of the shape
"""

let ovalShapeDescription = """
Generates an Oval shape from a given position and radius

*Inputs*
• The X/Y location where the oval should be placed
• The radius of the circle

*Outputs*
• The generated Oval shape
"""

let roundedRectangleShapeDescription = """
Generates a Rounded Rectangle shape from a given position, size, and radius

*Inputs*
• The X/Y location where the rounded rectangle should be placed
• Width and Height
• Radius

*Outputs*
• The generated Rounded Rectangle shape
"""

let shapeToCommandsDescription = """
Takes a shape as input, and outputs the commands used to generate the shape. Can be used to create a new shape from an existing pone.

*Inputs*
• A shape to extract commands from

*Outputs*
• The commands used to generated the shape
"""

let triangleShapeDescription = """
Generates a Triangle shape from three given points.

*Inputs*
• X/Y of the First Point
• X/Y of the Second Point
• X/Y of the Third Point

*Outputs*
• The generated Triangle shape
"""

let unionDescription = """
Combines two or more shapes to generate a new shape.

*Inputs*
• Two shapes to generate the union with

*Outputs*
• The generated shape
"""

// MARK: Sensors and Hardware

let deviceMotionDescription = """
Returns the acceleration and rotation values of the device the patch is running on.

*Outputs*
• A Boolean indicating if the device is accelerating
• The acceleration values as an XYZ vector
• A Boolean indicating if the device is rotating
• The rotation values as an XYZ vector

"""

let hapticFeedbackDescription = """
A node that will trigger a haptic pulse.

*Inputs*
A pulse will trigger the haptic event when triggered.
"""

let keyboardDescription = """
Detects keyboard events and outputs a Bool when a specified event occurs

*Inputs*
• The keyboard event to listen for

*Outputs*
• A Bool that's set when the event occurs
"""

// MARK: Wireless Broadcasting

let wirelessBroadcasterDescription = """
Sends a value to a selected Wireless Receiver node. Useful for organizing large, complicated projects by replacing cables betwen patches.

*Inputs*
• Whatever value you would like to broadcast. Can be configured to be any value type.
"""

let wirelessReceiverDescription = """
Used with the Wireless Broadcaster node to route values across the graph. Useful for organizing large, complicated projects.

*Outputs*
• The value received from the corresponding broadcast node.
"""
