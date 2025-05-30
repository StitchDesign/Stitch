//
//  MapLayerNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 3/25/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import MapKit

//Lat/Long value for San Francisco, California, USA
let DEFAULT_MAP_LAT_LONG_POSITION = StitchPosition(x: 38, y: -122.5)
let DEFAULT_MAP_LAT_LONG_SPAN = StitchPosition(x: 1, y: 1)

extension LayerSize {
    static let DEFAULT_MAP_SIZE: Self = .init(width: 200, height: 500)
}

struct MapLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.map
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .mapType,
        .mapLatLong,
        .mapSpan,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
        .union(.layerEffects)
        .union(.strokeInputs)
        .union(.aspectRatio)
        .union(.sizing)
        .union(.pinning)
        .union(.layerPaddingAndMargin)
        .union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> some View {
        PreviewMapLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            mapType: viewModel.mapType.getMapType ?? .standard,
            latLong: viewModel.mapLatLong.getPoint?.toCGSize ?? .zero,
            span: viewModel.mapSpan.getPoint?.toCGSize ?? .zero,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? LayerSize.DEFAULT_MAP_SIZE,
            opacity: viewModel.opacity.getNumber ?? .zero,
            scale: viewModel.scale.getNumber ?? .zero,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect ,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}

let DEFAULT_MAP_LAYER_IMAGE_NAME = "defaultMapLayerImage"

struct PreviewMapLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer

    // Map-specific
    let mapType: StitchMapType
    let latLong: CGSize // "Position"
    let span: CGSize // lat-long delta
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    @ViewBuilder
    var mapView: some View {
        if document.isGeneratingProjectThumbnail {
            // TODO: use default map, e.g. Mercator projection?
            
            if let image = UIImage(named: "defaultMapLayerImage") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                EmptyView()
            }
        } else {
            StitchMapView(region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latLong.width, longitude: latLong.height), span: MKCoordinateSpan(latitudeDelta: span.width, longitudeDelta: span.height)),
                                             mapType: mapType.toMKMapType)
                .opacity(opacity)
        }
    }
    
    var body: some View {
        mapView.modifier(PreviewCommonModifier(
            document: document,
            graph: graph,
            layerViewModel: layerViewModel,
            isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: interactiveLayer,
            position: position,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ,
            size: size,
            scale: scale,
            anchoring: anchoring,
            blurRadius: blurRadius,
            blendMode: blendMode,
            brightness: brightness,
            colorInvert: colorInvert,
            contrast: contrast,
            hueRotation: hueRotation,
            saturation: saturation,
            pivot: .defaultPivot,
            shadowColor: shadowColor,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid,
            frameAlignment: .topLeading,
            clipForMapLayerProjetThumbnailCreation: document.isGeneratingProjectThumbnail))
    }
}

struct StitchMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let mapType: MKMapType

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = mapType
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = mapType
        if isValidRegion(region) {
            uiView.setRegion(region, animated: true)
        }
    }

    func isValidRegion(_ region: MKCoordinateRegion) -> Bool {
        let latitude = region.center.latitude
        let validLatitude = latitude >= -90.0 && latitude <= 90.0

        let longitude = region.center.longitude
        let validLongitude = longitude >= -180.0 && longitude <= 180.0

        let validSpan = region.span.latitudeDelta > 0.0 && region.span.longitudeDelta > 0.0
                        && region.span.latitudeDelta <= 180.0 && region.span.longitudeDelta <= 360.0

        return validLatitude && validLongitude && validSpan
    }
}

func mapTypeCoercer(_ values: PortValues) -> PortValues {
    values
        .map { $0.coerceToMapType() }
        .map(PortValue.mapType)
}

extension PortValue {
    // Takes any PortValue, and returns a StitchMapType
    func coerceToMapType() -> StitchMapType {
        switch self {
        case .mapType(let x):
            return x
        case .number(let x):
            return StitchMapType.fromNumber(x).getMapType ?? .defaultMapType
        default:
            return .defaultMapType
        }
    }
}

extension StitchMapType: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<StitchMapType> {
        PortValue.mapType
    }
}

extension StitchMapType {
    static let defaultMapType: StitchMapType = .standard

    var toMKMapType: MKMapType {
        switch self {
        case .standard:
            return .standard
        case .satellite:
            return .satellite
        case .hybrid:
            return .hybrid
        case .hybridFlyover:
            return .hybridFlyover
        case .satelliteFlyover:
             return .satelliteFlyover
        case .mutedStandard:
            return .mutedStandard
        }
    }

}
