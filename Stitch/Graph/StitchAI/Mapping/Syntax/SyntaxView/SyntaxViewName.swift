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
enum SyntaxViewName: String, Equatable, Codable, Hashable, CaseIterable {
    // ── Basic shapes & drawing ─────────────────────────────────────────────
    case rectangle
    case roundedRectangle
    case circle
    case ellipse
    case capsule
    case path
    case color
    case linearGradient
    case radialGradient
    case angularGradient
    case material
    case canvas

    // ── Text & images ──────────────────────────────────────────────────────
    case text
    case textField
    case secureField
    case label
    case image
    case asyncImage
    case symbolEffect

    // ── Layout containers ─────────────────────────────────────────────────
    case group, vStack, hStack, zStack
    case lazyVStack, lazyHStack, lazyVGrid, lazyHGrid, grid
    case spacer, divider, geometryReader, alignmentGuide

    // ── Lists & scrolling ─────────────────────────────────────────────────
    case scrollView, list, table, outlineGroup, forEach

    // ── Navigation & containers ───────────────────────────────────────────
    case navigationStack, navigationSplit, navigationLink
    case tabView, form, section

    // ── Controls ──────────────────────────────────────────────────────────
    case button, toggle, slider, stepper, picker, datePicker
    case gauge, progressView, link

    // ── Media & rich content ─────────────────────────────────────────────
    case videoPlayer, map, model3D, timelineView

    // ── Misc / effects wrappers ──────────────────────────────────────────
    case anyView, preview, timelineSchedule
}

// MARK: - String ↔︎ enum helpers
extension SyntaxViewName {
    /// Create from the identifier that appears in Swift source
    /// (`"Rectangle"`, `"Text"`, …). Falls back to `.custom`.
    init?(from identifier: String) {
        guard let rawValue = SyntaxViewName(rawValue: identifier) else { return nil }
        self = rawValue
    }
    
    var string: String { self.rawValue }

    /// Convert back to the Swift identifier string.
    var rawValue: String {
        switch self {
        case .rectangle:              return "Rectangle"
        case .roundedRectangle:       return "RoundedRectangle"
        case .circle:                 return "Circle"
        case .ellipse:                return "Ellipse"
        case .capsule:                return "Capsule"
        case .path:                   return "Path"
        case .color:                  return "Color"
        case .linearGradient:         return "LinearGradient"
        case .radialGradient:         return "RadialGradient"
        case .angularGradient:        return "AngularGradient"
        case .material:               return "Material"
        case .canvas:                 return "Canvas"

        case .text:                   return "Text"
        case .textField:              return "TextField"
        case .secureField:            return "SecureField"
        case .label:                  return "Label"
        case .image:                  return "Image"
        case .asyncImage:             return "AsyncImage"
        case .symbolEffect:           return "SymbolEffect"

        case .group:                  return "Group"
        case .vStack:                 return "VStack"
        case .hStack:                 return "HStack"
        case .zStack:                 return "ZStack"
        case .lazyVStack:             return "LazyVStack"
        case .lazyHStack:             return "LazyHStack"
        case .lazyVGrid:              return "LazyVGrid"
        case .lazyHGrid:              return "LazyHGrid"
        case .grid:                   return "Grid"
        case .spacer:                 return "Spacer"
        case .divider:                return "Divider"
        case .geometryReader:         return "GeometryReader"
        case .alignmentGuide:         return "AlignmentGuide"

        case .scrollView:             return "ScrollView"
        case .list:                   return "List"
        case .table:                  return "Table"
        case .outlineGroup:           return "OutlineGroup"
        case .forEach:                return "ForEach"

        case .navigationStack:        return "NavigationStack"
        case .navigationSplit:        return "NavigationSplitView"
        case .navigationLink:         return "NavigationLink"
        case .tabView:                return "TabView"
        case .form:                   return "Form"
        case .section:                return "Section"

        case .button:                 return "Button"
        case .toggle:                 return "Toggle"
        case .slider:                 return "Slider"
        case .stepper:                return "Stepper"
        case .picker:                 return "Picker"
        case .datePicker:             return "DatePicker"
        case .gauge:                  return "Gauge"
        case .progressView:           return "ProgressView"
        case .link:                   return "Link"

        case .videoPlayer:            return "VideoPlayer"
        case .map:                    return "Map"
        case .model3D:                return "Model3D"
        case .timelineView:           return "TimelineView"

        case .anyView:                return "AnyView"
        case .preview:                return "Preview"
        case .timelineSchedule:       return "TimelineSchedule"
        }
    }
    
    static let unsupportedViews: [Self] = Self.allCases.filter {
        !$0.isSupported
    }
    
    var isSupported: Bool {
        self.deriveLayer(args: []) != nil
    }
}
