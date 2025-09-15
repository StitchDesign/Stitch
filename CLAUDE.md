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