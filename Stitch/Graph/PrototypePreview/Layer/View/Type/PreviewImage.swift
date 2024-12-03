//
//  PreviewImage.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/22/21.
//

import SwiftUI
import StitchSchemaKit

let DEFAULT_PREVIEW_IMAGE_SIZE = CGSize(width: 200, height: 200).toLayerSize

// The actual display size we will use for an image
struct ImageDisplaySize: Codable, Equatable {

    // a CGSize created from LayerSize + parentSize + resourceSize;
    // adjusted to be appropriate to the scenario (autoAll, autoWidth, etc.)
    var size: CGSize

    var scenario: ImageDisplayScenario

    init(_ size: LayerSize, 
         parentSize: CGSize,
         resourceSize: CGSize) {
        
        self.scenario = ImageDisplayScenario(size)

        // Size before adjustment from scenario
        let size = size.asCGSize(parentSize: parentSize,
                                 resourceSize: resourceSize)

        self.size = self.scenario.adjustSizeByScenario(
            size,
            resourceSize: resourceSize)
    }

    // innline display case
    init(_ size: CGSize) {
        self.scenario = .regular
        self.size = size
    }
}

// Do you need to
enum ImageDisplayScenario: Codable, Equatable {

    case autoDimensions,
         autoWidthOnly,
         autoHeightOnly,
         regular

    init(_ size: LayerSize) {
        if size.width.isAuto && size.height.isAuto {
            self = .autoDimensions
        } else if size.width.isAuto && !size.height.isAuto {
            self = .autoWidthOnly
        } else if size.height.isAuto && !size.width.isAuto {
            self = .autoHeightOnly
        } else {
            // eg LayerSize was (CGFloat, CGFloat), or
            // (CGFloat, .parentParent(50)) or ... etc.
            self = .regular
        }
    }

    var atleastOneDimensionUsesAuto: Bool {
        switch self {
        case .autoDimensions, .autoWidthOnly, .autoHeightOnly:
            return true
        case .regular:
            return false
        }
    }
    
    func adjustSizeByScenario(_ size: CGSize,
                              resourceSize: CGSize) -> CGSize {
        switch self {

        // If both dimensions `auto`, then just use image's size.
        case .autoDimensions:
            return resourceSize
        case .autoWidthOnly:
            return adjustedImageSize(targetSize: size,
                                     resourceSize: resourceSize)
        case .autoHeightOnly:
            return adjustedImageSize(targetSize: size,
                                     resourceSize: resourceSize,
                                     useWidthRatio: true)
        case .regular:
            return size
        }
    }
}

// https://www.advancedswift.com/resize-uiimage-no-stretching-swift/

// Find out the actual size that SwiftUI's .aspectRatio(.fit) will produce,
// given our layer's size and image resource's size.
func adjustedImageSize(targetSize: CGSize,
                       resourceSize: CGSize,
                       useWidthRatio: Bool = false) -> CGSize {

    let widthRatio = targetSize.width / resourceSize.width
    let heightRatio = targetSize.height / resourceSize.height

    // We use widthRatio when height=auto
    let scaleFactor = useWidthRatio ? widthRatio : heightRatio

    return CGSize(width: resourceSize.width * scaleFactor,
                  height: resourceSize.height * scaleFactor)
}

// TODO: revisit with "grow" and "hug"
struct ImageDisplayView: View {

    let image: UIImage
    
    // The raw LayerSize in the image layer node's input; any of its `nil` dimensions will override the manually calculated image-display-size, since e.g. `width: nil` means we should set no actual frame dimension along that axis
    let imageLayerSize: LayerSize
    
    // The manually-calculated size of the image, taking into account which dimensions are "auto"
    let imageDisplaySize: ImageDisplaySize
    
    let opacity: Double
    
    // TODO: separate out this PortView thumbnail-display case; there everything should be much simpler, since we always have a static size and always .fit the image with preserverd aspect ratio
    var fitStyle: VisualMediaFitStyle? // nil when used by PortView to display thumbnail
    
    var isClipped: Bool

    var body: some View {
        let image = imageView // set aspectRatio, frame dimensions etc.
            // modifiers common to all image settings (regardless of auto, etc.)
            .opacity(opacity)

        if isClipped {
            return image.clipped()
                .eraseToAnyView()
        } else {
            return image
                .eraseToAnyView()
        }
    }

    var imageView: some View {
        let view = Image(uiImage: image)
            .resizable()

        switch imageDisplaySize.scenario {

        case .autoDimensions:
            if let fitStyle = fitStyle {
                return view
                    .aspectRatio(contentMode: fitStyle.asContentMode)
                // Use the explicit `imageDisplaySize`, since that was used for positioning and already correctly reflects the resource's size
                // TODO: Why did we have to provide this explicit .frame ?
                    .frame(width: imageDisplaySize.size.width,
                           height: imageDisplaySize.size.height)
                    .eraseToAnyView()
            } else {
                return EmptyView()
                    .eraseToAnyView()
            }

        /*
         Only one dimension `auto` = auto dimension changes according to non-auto dimension,
         such that we preserve aspectRatio.
         eg original image is 200x100, ie ratio of 2:1,
         and image layer node size is 100xAuto,
         so we end up with a 100x50 image in the preview window.

         We implement this by using non-auto dimension for both width and height in .frame,
         and using .fit style regardless of layer node's fitStyle.
         */
        case
            // ie width = auto, height = number;
            // width might be limited by aspect ratio + height
            .autoWidthOnly,

            // ie width = number, height = auto;
            // height might be limited by aspect ratio + width
            .autoHeightOnly:

            return view
                .aspectRatio(contentMode: .fit)
                .frame(width: imageLayerSize.width.isFill ? nil : imageDisplaySize.size.width,
                       height: imageLayerSize.height.isFill ? nil : imageDisplaySize.size.height)
                .eraseToAnyView()

        case .regular:
            // only use .aspectRatio for .fit style
            if let fitStyle = fitStyle, fitStyle == .fit {
                return view
                    .aspectRatio(contentMode: fitStyle.asContentMode)
                    .frame(width: imageDisplaySize.size.width,
                           height: imageDisplaySize.size.height)
                    .contentShape(Rectangle()) // for when image has shrunk smaller than explicit frame
                    .eraseToAnyView()
            }
            
            // Note: not much different than what this earlier PR had moved away from: https://github.com/StitchDesign/Stitch/pull/593/files
            // ... Yet behavior seems good.
            else if let fitStyle = fitStyle, fitStyle == .fill {
                return view
                    .aspectRatio(contentMode: fitStyle.asContentMode)
                    .frame(width: imageLayerSize.width.isFill ? nil : imageDisplaySize.size.width,
                           height: imageLayerSize.height.isFill ? nil : imageDisplaySize.size.height)
                    .contentShape(Rectangle()) // for when image has shrunk smaller than explicit frame
                    .eraseToAnyView()
            }
            
            else {
                return view
                    .frame(width: imageLayerSize.width.isFill ? nil : imageDisplaySize.size.width,
                           height: imageLayerSize.height.isFill ? nil : imageDisplaySize.size.height)
                    .eraseToAnyView()
            }
        }
    } // imageView
}

/// A checkered box image used for thumbnails in nodes representing no image has been selected.
struct NilImageView: View {
    var body: some View {
        ImageDisplayView(image: IMAGE_EMPTY, 
                         imageLayerSize: .init(INLINE_IMAGE_DISPLAY_SIZE.size),
                         imageDisplaySize: INLINE_IMAGE_DISPLAY_SIZE,
                         opacity: IMAGE_INLINE_DISPLAY_OPACITY,
                         fitStyle: .fit,
                         isClipped: IMAGE_INLINE_DISPLAY_CLIPPED)
    }
}

struct PreviewImageLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let image: UIImage
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let fitStyle: VisualMediaFitStyle
    let scale: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let pivot: Anchoring
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    let isClipped: Bool

    var imageDisplaySize: ImageDisplaySize {
        // actual calculated size at which we're displaying the image
        ImageDisplaySize(size,
                         parentSize: parentSize,
                         resourceSize: image.size)
    }

    var debugView: some View {
        Text("imageDisplaySize.size: \(imageDisplaySize.size.debugDescription)")
            .scaleEffect(2)
            .offset(y: 300)
    }

    var sizeForPlacement: LayerSize {
        // The size for anchoring etc. is actually just the 'image display size'; we treat `auto` as the image resource size, i.e. a hardcoded number
        .init(imageDisplaySize.size)
    }
    
    var body: some View {
        
        ImageDisplayView(image: image,
                         imageLayerSize: size,
                         imageDisplaySize: imageDisplaySize,
                         opacity: opacity,
                         fitStyle: fitStyle,
                         isClipped: isClipped)
        .modifier(LayerSizeReader(viewModel: layerViewModel,
                                 isPinnedViewRendering: isPinnedViewRendering))
        .modifier(PreviewWindowCoordinateSpaceReader(
            viewModel: layerViewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            pinMap: graph.pinMap))
        .modifier(PreviewCommonModifierWithoutFrame(
            document: document,
            graph: graph,
            layerViewModel: layerViewModel,
            isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            size: sizeForPlacement,
            scale: scale,
            anchoring: anchoring,
            blurRadius: blurRadius,
            blendMode: blendMode,
            brightness: brightness,
            colorInvert: colorInvert,
            contrast: contrast,
            hueRotation: hueRotation,
            saturation: saturation,
            pivot: pivot,
            shadowColor: shadowColor,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition))
    }
}
