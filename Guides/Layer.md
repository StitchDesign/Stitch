# Layer

A **layer** is a visual element that renders in the Prototype Preview window — everything from simple rectangles to 3D models. Layers are listed in the **Layer Sidebar** where you can reorder, group, and nest them just like in a traditional design tool. Layer properties (position, size, opacity, etc.) can be driven by the **Layer Inspector**, accessed by selecting the right-hand sidebar icon in the toolbar.

## Basic Shapes

### Canvas Sketch
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

### Oval
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

### Rectangle
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

### Shape
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


## Gradients & Fills

### Angular Gradient
Creates an angular gradient.

*Inputs*
* Center anchor
* Start color
* End color

### Color Fill
A layer for filling the preview window with a specified color.

*Inputs*
* A Bool for enabling/disabling the fill
* A color picker
* Opacity
* Z Index

### Linear Gradient
Creates a linear gradient.

*Inputs*
* Start anchor
* End anchor
* First color
* Second color

### Radial Gradient
Creates a radial gradient.

*Inputs*
* Start anchor
* Start color
* End color
* Second color


## Media

### Image
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

### Material
A Material Effect layer.

### Video
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

### Video Streaming
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


## UI Elements

### Map
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

### Progress Indicator
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

### SF Symbol
Creates an SF Symbol.

### Toggle Switch
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

### Text
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

### Text Field
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


## Containers & Layout

### Group
Groups multiple layers into a single composite layer. Use this to organize layers hierarchically and apply transforms, clipping, or effects to an entire set of child layers at once.

*Inputs*
* Layer contents (the child layers to render inside the group)
* Position (X/Y)
* Rotation X
* Rotation Y
* Rotation Z
* Size (Width/Height)
* Opacity
* Scale
* Anchoring
* Z-Index

### Hit Area
Adds interaction to a specific rectangle in the Preview Window.

*Inputs*
* A Boolean to Enable/Disable the Hit Area
* Position (X/Y)
* Size (Width / Height)
* Anchor
* Z Index
* A Boolean to toggle Setup Mode (visualizes the hit area)


## 3D & AR

### Box
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

### Cone
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

### Cylinder
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

### 3D Model
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

### Reality View
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

### Sphere
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

