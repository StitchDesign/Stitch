//
//  ViewKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//
import Foundation
import SwiftUI

enum SyntaxNameType {
    case view(SyntaxViewName)
    case value(SyntaxValueName)
}

extension SyntaxNameType {
    static func from(_ identifier: String) -> Self? {
        // Checks views first (arbitrarily)
        if let view = SyntaxViewName(rawValue: identifier) {
            return .view(view)
        }
        
        if let value = SyntaxValueName(rawValue: identifier) {
            return .value(value)
        }
        
        return nil
    }
    
    var isView: Bool {
        switch self {
        case .view:
            return true
        default:
            return false
        }
    }
}

// Supported custom value types
enum SyntaxValueName: String, Hashable, CaseIterable {
    case portValueDescription = "PortValueDescription"
    case cgPoint = "CGPoint"
}

// MARK: - String ↔︎ enum helpers
extension SyntaxViewName {
    /// Create from the identifier that appears in Swift source
    /// (`"Rectangle"`, `"Text"`, …). Falls back to `.custom`.
    static func from(_ identifier: String) -> Self? {
        SyntaxViewName(rawValue: identifier)
    }
        
    static let unsupportedViews: [Self] = Self.allCases.filter {
        !$0.isSupported
    }
    
    var isSupported: Bool {
        (try? self.deriveLayerData(id: .init(),
                                   args: [],
                                   modifiers: [],
                                   childrenLayers: [])) != nil
    }
    
    // TODO: phase this out by using proper closure-checking
    /// Returns true if this view type can have child views via closures
    /// (e.g., VStack { ... }, HStack { ... })
    var canHaveChildren: Bool {
        switch self {
        // Stack containers
        case .vStack, .hStack, .zStack:
            return true
        case .lazyVStack, .lazyHStack, .lazyVGrid, .lazyHGrid:
            return true
        
        // Layout containers
        case .grid, .group:
            return true
        
        // Scrollable containers
        case .scrollView, .list:
            return true
        
        // Navigation containers
        case .navigationStack, .navigationSplit, .tabView:
            return true
        
        // Form containers
        case .form, .section:
            return true
        
        // Special containers
        case .forEach, .geometryReader:
            return true
        
        // All other views cannot have children via closures
        default:
            return false
        }
    }
    
//    static let disabledViews: [Self] = Self.allCases.filter {
//        $0.deriveLayer() == nil
//    }
}


/// A growing catalogue of SwiftUI view types we recognise.
/// Use `ViewKind(from:)` to convert a textual identifier into a typed case;
/// use `.string` to go the other way.  Anything unknown is stored in `.custom`.
enum SyntaxViewName: String, Equatable, Codable, Hashable, CaseIterable, Sendable {
    case anyView = "AnyView"
    case angularGradient = "AngularGradient"
    case asyncImage = "AsyncImage"
    case button = "Button"
    case capsule = "Capsule"
    case canvas = "Canvas"
    case chart = "Chart"
    case circle = "Circle"
    case color = "Color"
    case colorPicker = "ColorPicker"
    case contentUnavailableView = "ContentUnavailableView"
    case controlGroup = "ControlGroup"
    case datePicker = "DatePicker"
    case divider = "Divider"
    case disclosureGroup = "DisclosureGroup"
    case ellipse = "Ellipse"
    case emptyView = "EmptyView"
    case forEach = "ForEach"
    case form = "Form"
    case gauge = "Gauge"
    case geometryReader = "GeometryReader"
    case grid = "Grid"
    case gridRow = "GridRow"
    case group = "Group"
    case groupBox = "GroupBox"
    case labeledContent = "LabeledContent"
    case label = "Label"
    case lazyHGrid = "LazyHGrid"
    case lazyHStack = "LazyHStack"
    case lazyVGrid = "LazyVGrid"
    case lazyVStack = "LazyVStack"
    case link = "Link"
    case map = "Map"
    case material = "Material"
    case menu = "Menu"
    case model3D = "Model3D"
    case navigationLink = "NavigationLink"
    case navigationStack = "NavigationStack"
    case navigationSplit = "NavigationSplitView"
    case navigationView = "NavigationView"
    case outlineGroup = "OutlineGroup"
    case path = "Path"
    case preview = "Preview"
    case progressView = "ProgressView"
    case radialGradient = "RadialGradient"
    case realityView = "RealityView"
    case rectangle = "Rectangle"
    case roundedRectangle = "RoundedRectangle"
    case sceneView = "SceneView"
    case scrollView = "ScrollView"
    case scrollViewReader = "ScrollViewReader"
    case section = "Section"
    case shareLink = "ShareLink"
    case slider = "Slider"
    case snapshotView = "SnapshotView"
    case spacer = "Spacer"
    case spriteView = "SpriteView"
    case stepper = "Stepper"
    case symbolEffect = "SymbolEffect"
    case tabView = "TabView"
    case text = "Text"
    case textEditor = "TextEditor"
    case textField = "TextField"
    case timelineSchedule = "TimelineSchedule"
    case timelineView = "TimelineView"
    case toggle = "Toggle"
    case tokenField = "TokenField"
    case toolBar = "ToolBar"
    case videoPlayer = "VideoPlayer"
    case viewThatFits = "ViewThatFits"
    case vStack = "VStack"
    case hStack = "HStack"
    case zStack = "ZStack"
    case list = "List"
    case image = "Image"
    case linearGradient = "LinearGradient"
    case secureField = "SecureField"
    case alignmentGuide = "AlignmentGuide"
    case table = "Table"
    case picker = "Picker"
}
