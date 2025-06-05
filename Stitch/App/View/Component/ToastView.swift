//
//  ToastView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/21/22.
//

import SwiftUI
import StitchSchemaKit
import Combine

/// Shows a temporary toast notification on the bottom of the view.
/// Source: https://swiftuirecipes.com/blog/swiftui-toast
struct BottomCenterToast<ToastContent>: ViewModifier where ToastContent: View {
    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>
    @State private var isShowing: Bool = false
    
    let willShow: Bool
    var config: ToastConfig = ToastConfig()
    var onExpireAction: (() -> Void)?
    
    @ViewBuilder var toastContent: () -> ToastContent

    init(willShow: Bool,
         config: ToastConfig,
         onExpireAction: (() -> Void)? = nil,
         toastContent: @escaping () -> ToastContent) {
        self.willShow = willShow
        self.config = config
        self.onExpireAction = onExpireAction
        self.toastContent = toastContent
        
        // Displays toast for specified seconds
        self.timer = Timer
            .publish(every: config.duration, on: .main, in: .common).autoconnect()
    }

    func body(content: Content) -> some View {
        ZStack {
            content

            if isShowing {
                VStack {
                    Spacer()
                    toastContent()
                }
                .transition(config.transition)
                
                // Common to all toasts
                .hoverEffect(.lift) // doesn't work?
                .padding(.horizontal, 16)
                .padding(.bottom, 22)
            }
        }
        .onChange(of: self.willShow, initial: true) {
            withAnimation {
                self.isShowing = self.willShow
            }
        }
        .onReceive(self.timer) { _ in
            if let onExpireAction = onExpireAction {
                onExpireAction()
            }
        }

        // Show toast UI when bool condition changes
        .animation(config.animation, value: willShow)
    }
}

struct ToastConfig {
    let duration: TimeInterval
    let transition: AnyTransition
    let animation: Animation

    init(textColor: Color = .white,
         duration: TimeInterval = 10,
         transition: AnyTransition = .slideInAndOut(edge: .bottom),
         animation: Animation = .stitchAnimation) {
        
        self.duration = duration
        self.transition = transition
        self.animation = animation
    }
}

extension View {
    func bottomCenterToast<ToastContent: View>(
        willShow: Bool,
        config: ToastConfig = ToastConfig(),
        onExpireAction: (() -> Void)?,
        @ViewBuilder toastContent: @escaping () -> ToastContent
    ) -> some View {
        
        self.modifier(
            BottomCenterToast(willShow: willShow,
                              config: config,
                              onExpireAction: onExpireAction,
                              toastContent: toastContent)
        )
    }
}
