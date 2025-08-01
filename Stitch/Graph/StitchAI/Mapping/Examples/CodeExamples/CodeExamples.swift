//
//  MappingCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/26/25.
//

import Foundation
import SwiftUI

// Just a namespace
struct MappingExamples { }

// helpful for writing
#if DEV_DEBUG
struct ExampleView: View {
    var body: some View {
        Color.yellow
    } // var body: some View
}
#endif

struct MappingCodeExample: Sendable {
    let title: String
    let code: String
}

extension MappingExamples {
    
    // TODO: break into separate pieces
    static let codeExamples: [MappingCodeExample] = [
        
        ViewModifierCodeExamples.colorInitInFillModifier,
        ViewModifierCodeExamples.paddingNoArgsModifier,
        
        // Color
        ColorCodeExamples.colorAsValue,
        ColorCodeExamples.colorAsView,
        
        // Font Modifiers
        FontCodeExamples.systemFontBody,
        FontCodeExamples.systemFontHeadline,
        FontCodeExamples.systemFontLargeTitle,
        FontCodeExamples.customSystemFont,
        FontCodeExamples.customSystemFontWithWeight,
        FontCodeExamples.customSystemFontWithDesign,
        FontCodeExamples.customSystemFontComplete,
        FontCodeExamples.fontWeightBold,
        FontCodeExamples.fontWeightLight,
        FontCodeExamples.fontDesignRounded,
        FontCodeExamples.fontDesignMonospaced,
        FontCodeExamples.fontDesignSerif,
        FontCodeExamples.combinedFontModifiers,
        FontCodeExamples.fontWithColorAndWeight,
        FontCodeExamples.stackWithDifferentFonts,
        FontCodeExamples.fontInScrollView,
        
        // ScrollView
        ScrollViewCodeExamples.scrollViewVStack,
        ScrollViewCodeExamples.scrollViewHStack,
        ScrollViewCodeExamples.scrollViewNotTopLevel,
        ScrollViewCodeExamples.scrollViewWithAllAxes,
        ScrollViewCodeExamples.scrollViewWithoutExplicitAxes,
        
        // Stacks
        StackCodeExamples.vstack,
        StackCodeExamples.zstack_rectangles,
        StackCodeExamples.zstack_with_modifier,
        StackCodeExamples.nested,
        StackCodeExamples.nested_with_scale,
        
        // ViewModifiers with multiple parameters
        MultiparameterViewModifierCodeExamples.position,
        MultiparameterViewModifierCodeExamples.offset,
        MultiparameterViewModifierCodeExamples.frame,
    
        // Constructor arguments
        ConstructorCodeExamples.roundedRectangle,
        ConstructorCodeExamples.text,
        ConstructorCodeExamples.text_with_color,
        ConstructorCodeExamples.image,
        
       // VarBody examples
        VarBodyCodeExamples.var_body,
        VarBodyCodeExamples.var_body_method,
        VarBodyCodeExamples.file_views,
        
        // Rotation modifier
        RotationModifierCodeExamples.rotationEffectBasic,
        RotationModifierCodeExamples.rotation3DEffectBasic,
        
        // PortValueDescription examples
        PortValueDescriptionCodeExamples.rectangleWithColorPVD,
        PortValueDescriptionCodeExamples.ellipseWithSizePVD,
        PortValueDescriptionCodeExamples.textWithOpacityPVD,
        PortValueDescriptionCodeExamples.rectangleWithBlurPVD,
        PortValueDescriptionCodeExamples.stackWithPortValueDescriptions,
        
        //        // // NOT YET SUPPORTED:
        //        RotationModifierCodeExamples.rotationEffectAnchor,
        //        RotationModifierCodeExamples.rotationEffectRadians,
        //        RotationModifierCodeExamples.rotation3DEffectPerspective,
    ]
}
