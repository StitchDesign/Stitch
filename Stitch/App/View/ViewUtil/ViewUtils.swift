//
//  ViewUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/25/22.
//

import SwiftUI
import StitchSchemaKit

typealias BindingOnSet<T> = (T) -> Void

// should also take 'on edit' and 'on commit' callbacks
func createBinding<T: Any>(_ value: T,
                           _ onSet: @escaping  BindingOnSet<T>) -> Binding<T> {
    Binding<T>.init {
        value
    } set: { (newValue: T) in
        onSet(newValue)
    }
}

struct UIKitOnTapModifier: ViewModifier {
    let onTapCallback: () -> Void

    func body(content: Content) -> some View {
        UIKitTappableWrapper() {
            onTapCallback()
        } view: {
            content
        }
    }
}

extension View {
    /// Used to update some `State` property given a Redux state boolean value.
    func stitchAnimated(willAnimateBinding: Binding<Bool>,
                        willAnimateState: Bool,
                        animation: Animation = .stitchAnimation) -> some View {
        self.modifier(StitchAnimated(willAnimateBinding: willAnimateBinding,
                                     willAnimateState: willAnimateState,
                                     animation: animation))
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }

    func frame(_ size: CGSize) -> some View {
        self.modifier(FrameModifierSize(size: size))
    }

    func width(_ width: CGFloat) -> some View {
        self.modifier(FrameModifierWidth(width: width))
    }

    func height(_ height: CGFloat) -> some View {
        self.modifier(FrameModifierHeight(height: height))
    }

    /// Modifier which evalutes if some view is contained within the view frame.
    /// This modifier is designed to call only when the parent view's body is getting evaluated, meaning this modifier
    /// shouldn't create extra render cycles.
    //    func viewFrameReader(valuesObserver: PortValuesObserver) -> some View {
    //        self.modifier(ViewFrameReader(valuesObserver: valuesObserver))    }
}

struct FrameModifierSize: ViewModifier {
    var size: CGSize

    func body(content: Content) -> some View {
        content.frame(width: size.width, height: size.height)
    }
}

struct FrameModifierWidth: ViewModifier {
    var width: CGFloat

    func body(content: Content) -> some View {
        content.frame(width: width)
    }
}

struct FrameModifierHeight: ViewModifier {
    var height: CGFloat

    func body(content: Content) -> some View {
        content.frame(height: height)
    }
}
