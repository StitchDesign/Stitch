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

        // Classic Animation Bug Test - Issue #7505
        ClassicAnimationCodeExamples.phoneKeypadWithButtonAnimations,

        // Math expressions in PortValueDescription - TESTING NEW FEATURE
        PortValueDescriptionCodeExamples.rectangleWithDragGestureMathExpressions,
        PortValueDescriptionCodeExamples.ellipseWithStaticMathExpressions,

        // Background examples - testing background to ZStack transformation
        BackgroundCodeExamples.simpleBackgroundFunctionCall,
        BackgroundCodeExamples.simpleBackgroundClosure,
        BackgroundCodeExamples.multipleChildrenBackground,
        BackgroundCodeExamples.vstackBackground,
        BackgroundCodeExamples.complexBackgroundWithModifiers,
        BackgroundCodeExamples.nestedBackground,
        
        // New background examples with modifiers - testing the fix for view modifier parsing
        BackgroundCodeExamples.backgroundTextWithForegroundColor,
        BackgroundCodeExamples.backgroundVStackWithModifiers,
        
        // Overlay examples - testing overlay to ZStack transformation
        OverlayCodeExamples.simpleOverlayFunctionCall,
        OverlayCodeExamples.simpleOverlayClosure,
        OverlayCodeExamples.multipleChildrenOverlay,
        OverlayCodeExamples.vstackOverlay,
        OverlayCodeExamples.complexOverlayWithModifiers,
        OverlayCodeExamples.nestedOverlay,
        
        // New overlay examples with modifiers - testing the fix for view modifier parsing
        OverlayCodeExamples.overlayTextWithForegroundColor,
        OverlayCodeExamples.overlayVStackWithModifiers,
        OverlayCodeExamples.overlayTextWithPortValueDescription,
        OverlayCodeExamples.overlayWithFrameModifier,
        OverlayCodeExamples.overlayWithClosureSyntax,
                
        // OLDER
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
        FontCodeExamples.fontWithPortValueDescription,
        
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
        
        // Grids
        GridCodeExamples.simpleGrid,
        GridCodeExamples.phoneKeypadGrid,
        GridCodeExamples.gridWithDifferentItems,
        
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
        PortValueDescriptionCodeExamples.textWithFontSizePVD,
        
        // Rotation with PortValueDescription examples
        RotationModifierCodeExamples.rotationEffectPortValueDescription,
        RotationModifierCodeExamples.rotation3DEffectPortValueDescription,
        RotationModifierCodeExamples.rotationEffectPortValueDescriptionVariable,
        RotationModifierCodeExamples.rotation3DEffectPortValueDescriptionMultiAxis,
        
        // Preprocessing examples - testing our new multiple root view logic
        PreprocessingCodeExamples.singleRootView,
        PreprocessingCodeExamples.multipleRootViews,
        PreprocessingCodeExamples.singleStackWithChildren,
        PreprocessingCodeExamples.mixedMultipleViews,
        PreprocessingCodeExamples.phoneKeypadExample,
        PreprocessingCodeExamples.complexNestedExample,
        
        //        // // NOT YET SUPPORTED:
        //        RotationModifierCodeExamples.rotationEffectAnchor,
        //        RotationModifierCodeExamples.rotationEffectRadians,
        //        RotationModifierCodeExamples.rotation3DEffectPerspective,
    ]
}

