//
//  ViewKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//
import Foundation
import SwiftUI

/// A growing catalogue of SwiftUI view types we recognise.
/// Use `ViewKind(from:)` to convert a textual identifier into a typed case;
/// use `.string` to go the other way.  Anything unknown is stored in `.custom`.
enum SyntaxViewName: String, Equatable, Codable, Hashable, CaseIterable, Sendable {
    case rectangle = "Rectangle"
    case roundedRectangle = "RoundedRectangle"
    case circle = "Circle"
    case ellipse = "Ellipse"
    case capsule = "Capsule"
    case path = "Path"
    case color = "Color"
    case linearGradient = "LinearGradient"
    case radialGradient = "RadialGradient"
    case angularGradient = "AngularGradient"
    case material = "Material"
    case canvas = "Canvas"

    case text = "Text"
    case textField = "TextField"
    case secureField = "SecureField"
    case label = "Label"
    case image = "Image"
    case asyncImage = "AsyncImage"
    case symbolEffect = "SymbolEffect"

    case group = "Group"
    case vStack = "VStack"
    case hStack = "HStack"
    case zStack = "ZStack"
    case lazyVStack = "LazyVStack"
    case lazyHStack = "LazyHStack"
    case lazyVGrid = "LazyVGrid"
    case lazyHGrid = "LazyHGrid"
    case grid = "Grid"
    case spacer = "Spacer"
    case divider = "Divider"
    case geometryReader = "GeometryReader"
    case alignmentGuide = "AlignmentGuide"

    case scrollView = "ScrollView"
    case list = "List"
    case table = "Table"
    case outlineGroup = "OutlineGroup"
    case forEach = "ForEach"

    case navigationStack = "NavigationStack"
    case navigationSplit = "NavigationSplitView"
    case navigationLink = "NavigationLink"
    case tabView = "TabView"
    case form = "Form"
    case section = "Section"

    case button = "Button"
    case toggle = "Toggle"
    case slider = "Slider"
    case stepper = "Stepper"
    case picker = "Picker"
    case datePicker = "DatePicker"
    case gauge = "Gauge"
    case progressView = "ProgressView"
    case link = "Link"

    case videoPlayer = "VideoPlayer"
    case map = "Map"
    case model3D = "Model3D"
    case timelineView = "TimelineView"

    case anyView = "AnyView"
    case preview = "Preview"
    case timelineSchedule = "TimelineSchedule"
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


