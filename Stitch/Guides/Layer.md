# Layer Nodes

## Angular Gradient
Creates an angular gradient.

*Inputs*
* Center anchor
* Start color
* End color

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

## Color Fill
A layer for filling the preview window with a specified color.

*Inputs*
* A Bool for enabling/disabling the fill
* A color picker
* Opacity
* Z Index

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

## Cylinder
A cylinder 3D shape, which can be used inside a Reality View.

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

## Group


## Hit Area
Adds interaction to a specific rectangle in the Preview Window.

*Inputs*
* A Boolean to Enable/Disable the Hit Area
* Position (X/Y)
* Size (Width / Height)
* Anchor
* Z Index
* A Boolean to toggle Setup Mode (visualizes the hit area)

## Image
The Image node is a Layer that will display an image asset in the Preview Window.

*Inputs*
* An image asset
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Fill Style
* Scale
* Anchoring
* Z-Index
* Clipped (Boolean)

## Linear Gradient
Creates a linear gradient.

*Inputs*
* Start anchor
* End anchor
* First color
* Second color

## Map
The Map node will display an Apple Maps UI in the preview window. 

*Inputs*
* Map Style
* Latitude / Longitude
* Span
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Stroke Position
* Stroke Width
* Stroke Color

## Material
A Material Effect layer.

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

## Oval
The Oval Layer will display an Oval shape in the Preview Window.

*Inputs*
* Color
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Stroke Position
* Stroke Width
* Stroke Color

## Progress Indicator
The Progress Indicator will display a Progress Indicator animation.

*Inputs*
* Animating
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Stroke Position
* Stroke Width
* Stroke Color

## Radial Gradient
Creates a radial gradient.

*Inputs*
* Start anchor
* Start color
* End color
* Second color

## Reality View
The RealityView node will display the output of an Augmented Reality scene in the form of a layer group. Drag 3D layers inside the Reality View sidebar item to display 3D objects in the scene.

*Inputs*
* Camera Direction (Front / Back)
* Position (X / Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (Width / Height)
* Opacity
* Scale
* Anchoring
* Z Index
* Camera Toggle
* Toggle for enabling/disabling shadows in the scene

## Rectangle
The Rectangle Layer will display a rectangle shape in the Preview Window.

*Inputs*
* Color
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Stroke Position
* Stroke Width
* Stroke Color
* Corner Radius

## SF Symbol
Creates an SF Symbol.

## Shape
The Shape Layer can take a shape as an input and display it in the preview window. The shape can be modified via a variety of inputs.

*Inputs*
* Shape
* Color
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (Width/Height)
* Opacity
* Scale
* Anchoring
* Z Index
* Stroke Position (Inside or Outside)
* Stroke Width
* Stroke Color
* Coordinate System (Relative or Absolute)

## Sphere
A sphere 3D shape, which can be used inside a Reality View.

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

## Toggle Switch
Displays an interactive UI toggle switch. 

*Inputs*
* Enabled
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Scale
* Anchoring
* Z-Index
* Stroke Position
* Stroke Width

## Text
Displays a text value in the preview window.

*Inputs*
* Text value (a string)
* Color
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (Width / Height)
* Opacity
* Scale
* Anchoring
* Z Index
* Font Size
* Alignment
* Vertical Alignment

## Text Field
Enter text into the preview window.

*Inputs*
* Placeholder (a string)
* Color
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (Width / Height)
* Opacity
* Scale
* Anchoring
* Z Index
* Font Size
* Alignment

## Video
The Video Layer displays a video asset in the preview window.

*Inputs*
* A video asset
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Fill Style
* Scale
* Anchoring
* Z-Index
* Clipped (Boolean)

## Video Streaming
The Video Streaming Layer streams a video from a given URL string.

*Inputs*
* A URL to stream a video from
* Volume
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (W/H)
* Opacity
* Fill Style
* Scale
* Anchoring
* Z-Index
* Clipped (Boolean)
