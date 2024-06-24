//
//  ToastView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/21/22.
//

import SwiftUI
import StitchSchemaKit

/// Shows a temporary toast notification on the bottom of the view.
/// Source: https://swiftuirecipes.com/blog/swiftui-toast
struct Toast: ViewModifier {
    let willShow: Bool
    let messageLeft: String
    let messageRight: String
    var config: ToastConfig = ToastConfig()
    var onTapAction: (() -> Void)?
    var onExpireAction: (() -> Void)?

    // Displays toast for 10 seconds
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    @State var isShowing: Bool = false

    func body(content: Content) -> some View {
        ZStack {
            content

            if isShowing {
                toastView.transition(config.transition)
            }
        }
        .onChange(of: self.willShow, initial: true) {
            self.isShowing = self.willShow
        }
        .onReceive(self.timer) { _ in
            if let onExpireAction = onExpireAction {
                onExpireAction()
            }
        }

        // Show toast UI when bool condition changes
        .animation(config.animation, value: willShow)
    }

    private var toastView: some View {
        VStack {
            Spacer()
            StitchButton(action: {
                if let onTapAction = onTapAction {
                    onTapAction()
                }
            }, label: {
                Text(messageLeft)
                Divider()
                    .width(1)
                    .overlay(.white)
                Text(messageRight)
            })
            .opacity(0.8)
            .font(.system(size: 14))
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(uiColor: .systemGray4))
            .cornerRadius(22)
            .hoverEffect(.lift)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }
}

struct Toast_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            VStack {}
                .frame(geometry.size)
        }
        .previewDevice(IPAD_PREVIEW_DEVICE_NAME)
        .modifier(Toast(willShow: true,
                        messageLeft: "File Deleted",
                        messageRight: "Undo",
                        isShowing: true))
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
    func toast(willShow: Bool,
               messageLeft: String,
               messageRight: String,
               config: ToastConfig = ToastConfig(),
               onTapAction: (() -> Void)? = nil,
               onExpireAction: (() -> Void)?) -> some View {
        self.modifier(Toast(willShow: willShow,
                            messageLeft: messageLeft,
                            messageRight: messageRight,
                            config: config,
                            onTapAction: onTapAction,
                            onExpireAction: onExpireAction))
    }
}
