//
//  ShimmerEffectViewModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/4/25.
//

import SwiftUI
import Shimmer

// MARK: - Custom Shimmer Effect (for Light Mode)

// Shimmer Config
struct CustomShimmerConfig {
    var tint: Color
    var highlight: Color
    var blur: CGFloat = 0
    var highlightOpacity: CGFloat = 1
    var speed: CGFloat = 2
}

struct CustomShimmerEffectHelper: ViewModifier {
    // Shimmer Config
    var config: CustomShimmerConfig
    // Animation Properties
    @State private var moveTo: CGFloat = -0.7
    
    func body(content: Content) -> some View {
        content
        // Adding Shimmer Animation with the help of Masking Modifier
            .overlay {
                // Changing Tint Color
                Rectangle()
                    .fill(config.tint)
                    .mask {
                        content
                    }
                    .overlay {
                        // Shimmer
                        GeometryReader {
                            let size = $0.size
                            let extraOffset = size.height / 2.5
                            
                            Rectangle()
                                .fill(config.highlight)
                                .mask {
                                    Rectangle()
                                    // Gradient For Glowing at the Center
                                        .fill(
                                            .linearGradient(colors: [
                                                .white.opacity(0),
                                                config.highlight.opacity(config
                                                    .highlightOpacity),
                                                .white.opacity(0)
                                            ], startPoint: .top, endPoint: .bottom)
                                        )
                                }
                            // Adding Blur
                                .blur(radius: config.blur)
                            // Rotating (Degree: Your Choice of Wish)
                                .rotationEffect(.init(degrees: -70))
                            // Moving to the Start
                                .offset(x: moveTo > 0 ? extraOffset : -extraOffset)
                                .offset(x: size.width * moveTo)
                        }
                    }
                    .mask {
                        content
                    }
            }
        // Animating Movement
            .onAppear {
                DispatchQueue.main.async {
                    moveTo = 0.7
                }
            }
            .animation(.linear(duration: config.speed).repeatForever(autoreverses: false), value: moveTo)
    }
}

extension View {
    @ViewBuilder
    func customShimmer(_ config: CustomShimmerConfig) -> some View {
        self
            .modifier(CustomShimmerEffectHelper(config: config))
    }
}

// MARK: - Hybrid Shimmer Modifier

struct HybridShimmerModifier: ViewModifier {
    let colorScheme: ColorScheme
    let lightModeConfig: CustomShimmerConfig
    
    func body(content: Content) -> some View {
        switch colorScheme {
        case .dark:
            // Use SwiftUI-Shimmer package for dark mode with matching duration
            content.shimmering(duration: lightModeConfig.speed)
        case .light:
            // Use custom shimmer for light mode
            content.customShimmer(lightModeConfig)
        @unknown default:
            // Fallback to light mode behavior
            content.customShimmer(lightModeConfig)
        }
    }
}
