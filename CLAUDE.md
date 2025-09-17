# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building for Different Platforms
- **macOS Catalyst**: `xcodebuild -scheme "Stitch Dev Debug" -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
- **Standard iOS/macOS**: Open `Stitch.xcodeproj` in Xcode and build normally

### Testing
- **Run tests**: Use Xcode test runner or `xcodebuild test -scheme "Stitch Dev Debug"`
- **Test configuration**: Defined in `Stitch.xctestplan`
- **Key test directories**: `StitchTests/` contains unit tests for math, loops, JSON, preview layers, and SwiftUI parsing

### Linting
- **SwiftLint configuration**: `.swiftlint.yml` with relaxed rules for identifier names, line length, and complexity
- **Run linting**: `swiftlint` (if installed)

## Architecture Overview

Stitch is a visual programming and prototyping environment built natively for Apple platforms, supporting iPad, iPhone, and macOS.

### Core Architecture Components

1. **Graph System** (`Stitch/Graph/`):
   - **Patches**: Logic nodes with typed input/output ports located in `Graph/Node/Patch/Type/`
   - **Layers**: Visual elements managed in `Graph/LayerInspector/` and sidebar
   - **Edges**: Connections between patches that pass data each frame

2. **Node System** (`Stitch/Graph/Node/`):
   - **PatchNodeDefinition**: Protocol defining patch behavior and port structure
   - **Node Types**: Math, Animation, Color, Data, Loop, Shape, Text, Device nodes
   - **Evaluation System**: Frame-based execution with type coercion and async media handling

3. **Visual Programming Interface**:
   - **Patch Canvas**: Main logic workspace for connecting nodes
   - **Layer Sidebar**: Hierarchical visual element management
   - **Preview Window**: Real-time prototype rendering and interaction

4. **StitchAI** (`Stitch/Graph/StitchAI/`):
   - Natural language graph generation (limited to ~6 nodes)
   - AI schema versioning system with structured request/response types

### Key Patterns

- **Patch Nodes**: Each patch type has a struct implementing `PatchNodeDefinition` with `rowDefinitions()` and corresponding evaluation function
- **Port Values**: Strongly typed system with coercion between compatible types (PortValue enum)
- **Graph State**: Redux-like state management with actions and reducers
- **CloudKit Integration**: iCloud syncing for cross-device document access
- **SwiftUI Architecture**: Native Apple framework usage throughout

### File Organization

- `Stitch/Graph/Node/Patch/Type/`: Individual patch node implementations organized by category
- `Stitch/Graph/Model/`: Core data models and state management
- `Stitch/Graph/View/`: SwiftUI views for the visual interface
- `Stitch/Graph/Util/`: Utility functions for evaluation, coercion, and helpers
- `StitchTests/`: Unit tests covering evaluation, topology, and file handling

### Development Setup Requirements

- Xcode with Apple Developer account
- CloudKit container setup required for iCloud features
- Bundle ID customization needed for local development
- Push notification entitlements for collaborative features

## Important Implementation Notes

- **Apple Ecosystem Focus**: Built specifically for ARKit, CoreML, iCloud, and SwiftUI
- **Touch-First Design**: Optimized for iPad interaction patterns
- **Real-Time Evaluation**: Graph executes every frame with live preview updates
- **Type Safety**: Strong typing system with runtime coercion between compatible types
- **Extensible Node System**: New patch types follow consistent `PatchNodeDefinition` protocol

## StitchSchemaKit V33 - Complete Architecture Guide

  Repository & Access

- GitHub: https://github.com/StitchDesign/StitchSchemaKit
- Local Path: ~/Local Documents/wissenschaft/StitchDesign/StitchSchemaKit
- Version Pattern: Always use highest version (e.g., _V33 > _V32)
- File Organization: Sources/StitchSchemaKit/V{version}/{category}/{TypeName}_V{version}.swift

  Core Philosophy

- Version Migration System: Every type has StitchVersionedCodable for automatic migration
- Type Safety: ~100 distinct types for maximum compile-time safety
- Separation of Concerns: Schema (data) separated from runtime (ViewModels)

  Core Data Types

  NodeEntity_V33

  struct NodeEntity {
      let id: UUID
      var nodeTypeEntity: NodeTypeEntity  // .patch, .layer, .group, .component
      let title: String
  }

  PortValue_V33

- Location: /V33/NodePort/PortValue_V33.swift
- Enum with ~60 cases including:
  - Basic: .string(), .bool(), .number(), .color()
  - Geometry: .position(), .size(), .point3D(), .transform()
  - Media: .asyncMedia(), .json()
  - Layer-specific: .layerDimension(), .anchoring(), .layerStroke()
  - Special: .pulse(), .none, .assignedLayer()
- Used for all node input/output values

  UserVisibleType_V33

- Location: /V33/UserVisibleType_V33.swift
- CaseIterable enum - simplified type system for UI
- Maps to PortValue types but simpler (no associated values)
- Used for type checking/coercion in UI

  Graph Structure Hierarchy

  GraphEntity
  ├── nodes: [NodeEntity]
  │   ├── id: UUID
  │   ├── title: String
  │   └── nodeTypeEntity: NodeTypeEntity
  │       ├── .patch(PatchNodeEntity)
  │       ├── .layer(LayerNodeEntity)
  │       ├── .group(CanvasNodeEntity)
  │       └── .component(ComponentEntity)
  ├── orderedSidebarLayers: [SidebarLayerData]
  └── commentBoxes: [CommentBoxData]

  Key Type Categories

1. Node Types

- NodeEntity: Core wrapper with id, title, nodeTypeEntity
- PatchNodeEntity: Logic nodes with 186 patch types
  - Has canvasEntity for position/size
  - Has inputs: [NodePortInputEntity]
  - Special types: splitter, mathExpression, javascript
- LayerNodeEntity: Visual elements with 45 layer types
  - ~100 input ports (position, size, opacity, etc.)
  - Each port is LayerInputEntity with packed/unpacked data
  - Canvas items stored in LayerInputDataEntity.canvasItem

2. Port System

- NodeConnectionType: Either .values([PortValue]) or .upstreamConnection(NodeIOCoordinate)
- NodeIOCoordinate: Identifies specific port (portType + nodeId)
- NodePortInputEntity: Stores connection data for patch inputs
- LayerInputEntity: Wrapper for layer port data with packed/unpacked arrays

3. Value System

- PortValue: ~60 cases - the actual runtime values
  - Primitives: .string(), .bool(), .number(), .color()
  - Geometry: .position(), .size(), .transform(), .point3D()
  - Media: .asyncMedia(), .json(), .shape()
  - Special: .pulse(), .none, .assignedLayer()
- UserVisibleType: Simplified enum for UI type checking (no associated values)

4. Patch Types (186 total)

  Common categories:
- Math: add, multiply, divide, mod, power
- Logic: equals, greaterThan, and, or, not
- Animation: springAnimation, classicAnimation, curve
- Data: jsonObject, valueForKey, arrayAppend
- Media: imageImport, videoImport, cameraFeed
- Interaction: dragInteraction, pressInteraction, keyboard
- Special: javascript, mathExpression, soulver

5. Layer Types (45 total)

- Basic: text, oval, rectangle, image
- Containers: group, hitArea
- Gradients: linearGradient, radialGradient, angularGradient
- 3D: model3D, realityView, box, sphere, cylinder
- Interactive: textField, switchLayer, map
- Effects: material, colorFill

  Important Patterns

  Version Migration

  public enum TypeName_V33: StitchSchemaVersionable {
      public static let version = StitchSchemaVersion._V33
      public typealias PreviousInstance = TypeName_V32.TypeName

      public struct TypeName: StitchVersionedCodable {
          public init(previousInstance: PreviousInstance) {
              // Migration logic
          }
      }
  }

  Layer Input Access

  // Each LayerNodeEntity has ~100 ports like:
  positionPort: LayerInputEntity
  sizePort: LayerInputEntity
  opacityPort: LayerInputEntity

  // LayerInputEntity contains:
  packedData: LayerInputDataEntity  // Single value
  unpackedData: [LayerInputDataEntity]  // Loop values

  // LayerInputDataEntity has:
  inputPort: NodeConnectionType  // Values or upstream connection
  canvasItem: CanvasNodeEntity?  // When dragged to canvas

  Sidebar Structure

  SidebarLayerData {
      id: UUID  // Matches node ID
      children: [SidebarLayerData]?  // Nested groups
      isExpandedInSidebar: Bool?
  }

  Canvas Positioning

  CanvasNodeEntity {
      position: CGPoint
      zIndex: Double
      parentGroupNodeId: GroupNodeID?
  }

  Critical Files for Reference

1. Graph: GraphEntity_V33.swift - Top-level structure
2. Nodes: NodeEntity_V33.swift, NodeTypeEntity_V33.swift
3. Patches: Patch_V33.swift, PatchNodeEntity_V33.swift
4. Layers: Layer_V33.swift, LayerNodeEntity_V33.swift
5. Ports: PortValue_V33.swift, NodePortType_V33.swift
6. Connections: NodeIOCoordinate_V33.swift, NodeConnectionType_V33.swift

  Key Insights

- Immutable Schema: All schema types are value types (structs/enums)
- UUID-based: Everything identified by UUIDs for stability
- Recursive Structures: Groups/components can contain full graphs
- Type Explosion: Intentionally many types for safety over simplicity
- Canvas vs Sidebar: Same nodes represented differently in each view

