//
//  SchemaVersions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/21/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

public typealias Anchoring = CurrentAnchoring.Anchoring
public typealias AsyncMediaValue = CurrentAsyncMediaValue.AsyncMediaValue
public typealias CameraDirection = CurrentCameraDirection.CameraDirection
public typealias ClassicAnimationCurve = CurrentClassicAnimationCurve.ClassicAnimationCurve
public typealias CameraSettings = CurrentCameraSettings.CameraSettings
public typealias CommentBoxData = CurrentCommentBoxData.CommentBoxData
public typealias CustomShape = CurrentCustomShape.CustomShape
public typealias DataType = CurrentDataType.DataType
public typealias DateAndTimeFormat = CurrentDateAndTimeFormat.DateAndTimeFormat
public typealias DelayStyle = CurrentDelayStyle.DelayStyle
public typealias ExpansionDirection = CurrentExpansionDirection.ExpansionDirection
public typealias GroupNodeId = CurrentGroupNodeIDCoordinate.GroupNodeId
public typealias JSONCurveTo = CurrentJSONCurveTo.JSONCurveTo
public typealias JSONShapeCommand = CurrentJSONShapeCommand.JSONShapeCommand
public typealias JSONShapeKeys = CurrentJSONShapeKeys.JSONShapeKeys
public typealias Layer = CurrentLayer.Layer
public typealias LayerDimension = CurrentLayerDimension.LayerDimension
public typealias LayerNodeEntity = CurrentLayerNodeEntity.LayerNodeEntity
public typealias LayerNodeId = CurrentLayerNodeId.LayerNodeId
public typealias LayerSize = CurrentLayerSize.LayerSize
public typealias LayerTextDecoration = CurrentLayerTextDecoration.LayerTextDecoration
public typealias LayerStroke = CurrentLayerStroke.LayerStroke
public typealias LayerTextAlignment = CurrentLayerTextAlignment.LayerTextAlignment
public typealias LayerTextVerticalAlignment = CurrentLayerTextVerticalAlignment.LayerTextVerticalAlignment
public typealias LightType = CurrentLightType.LightType
public typealias MobileHapticStyle = CurrentMobileHapticStyle.MobileHapticStyle
public typealias MediaKey = CurrentMediaKey.MediaKey
public typealias NetworkRequestType = CurrentNetworkRequestType.NetworkRequestType
//public typealias NodeEntity = CurrentNodeEntity.NodeEntity
public typealias NodeKind = CurrentNodeKind.NodeKind
public typealias NodeIOCoordinate = CurrentNodeIOCoordinate.NodeIOCoordinate
public typealias NodePortInputEntity = CurrentNodePortInputEntity.NodePortInputEntity
public typealias Patch = CurrentPatch.Patch
public typealias PatchNodeEntity = CurrentPatchNodeEntity.PatchNodeEntity
public typealias PathPoint = CurrentPathPoint.PathPoint
public typealias Plane = CurrentPlane.Plane
#if !os(visionOS)
public typealias Point3D = CurrentPoint3D.Point3D
#endif
public typealias Point4D = CurrentPoint4D.Point4D
public typealias PortValue = CurrentPortValue.PortValue
public typealias PortValueComparable = CurrentPortValueComparable.PortValueComparable
public typealias PreviewSize = CurrentPreviewSize.PreviewSize
public typealias ProgressIndicatorStyle = CurrentStitchProgressIndicatorStyle.ProgressIndicatorStyle
public typealias RGBA = CurrentRGBA.RGBA
public typealias RoundedRectangleData = CurrentRoundedRectangleData.RoundedRectangleData
public typealias ScrollDecelerationRate = CurrentScrollDecelerationRate.ScrollDecelerationRate
public typealias ScrollJumpStyle = CurrentScrollJumpStyle.ScrollJumpStyle
public typealias ScrollMode = CurrentScrollMode.ScrollMode
public typealias ShapeAndRect = CurrentShapeAndRect.ShapeAndRect
public typealias ShapeCommand = CurrentShapeCommand.ShapeCommand
public typealias ShapeCommandType = CurrentShapeCommandType.ShapeCommandType
public typealias ShapeCoordinates = CurrentShapeCoordinates.ShapeCoordinates
public typealias SidebarLayerData = CurrentSidebarLayerData.SidebarLayerData
public typealias SplitterType = CurrentSplitterType.SplitterType
public typealias SplitterNodeEntity = CurrentSplitterNodeEntity.SplitterNodeEntity
//public typealias StitchDocument = CurrentStitchDocument.StitchDocument
public typealias StitchBlendMode = CurrentStitchBlendMode.StitchBlendMode
public typealias StitchCameraOrientation = CurrentStitchCameraOrientation.StitchCameraOrientation
public typealias StitchDeviceOrientation = CurrentStitchDeviceOrientation.StitchDeviceOrientation
public typealias StitchMapType = CurrentStitchMapType.StitchMapType
public typealias StitchFont = CurrentStitchFont.StitchFont
public typealias StitchFontChoice = CurrentStitchFontChoice.StitchFontChoice
public typealias StitchFontWeight = CurrentStitchFontWeight.StitchFontWeight
public typealias StitchJSON = CurrentStitchJSON.StitchJSON
public typealias StitchOrientation = CurrentStitchOrientation.StitchOrientation
public typealias TextTransform = CurrentTextTransform.TextTransform
public typealias TriangleData = CurrentTriangleData.TriangleData
public typealias UserVisibleType = CurrentUserVisibleType.UserVisibleType
public typealias VisualMediaFitStyle = CurrentVisualMediaFitStyle.VisualMediaFitStyle
public typealias NodeConnectionType = CurrentNodeConnectionType.NodeConnectionType
public typealias LayerInputType = CurrentLayerInputType.LayerInputType
public typealias NodeIOPortType = CurrentNodeIOPortType.NodeIOPortType
public typealias StrokeLineCap = CurrentStrokeLineCap.StrokeLineCap
public typealias StrokeLineJoin = CurrentStrokeLineJoin.StrokeLineJoin
public typealias StitchStringValue = CurrentStitchStringValue.StitchStringValue
public typealias StitchContentMode = CurrentStitchContentMode.StitchContentMode
public typealias StitchSpacing = CurrentStitchSpacing.StitchSpacing
public typealias StitchPadding = CurrentStitchPadding.StitchPadding
public typealias SizingScenario = CurrentSizingScenario.SizingScenario
//public typealias NodeTypeEntity = CurrentNodeTypeEntity.NodeTypeEntity
public typealias CanvasNodeEntity = CurrentCanvasNodeEntity.CanvasNodeEntity
public typealias LayerInputDataEntity = CurrentLayerInputDataEntity.LayerInputDataEntity
public typealias CanvasItemId = CurrentCanvasItemId.CanvasItemId
public typealias LayerInputCoordinate = CurrentLayerInputCoordinate.LayerInputCoordinate
public typealias LayerOutputCoordinate = CurrentLayerOutputCoordinate.LayerOutputCoordinate
public typealias PinToId = CurrentPinToId.PinToId
public typealias LayerInputEntity = CurrentLayerInputEntity.LayerInputEntity
public typealias LayerInputPort = CurrentLayerInputPort.LayerInputPort
public typealias LayerInputKeyPathType = CurrentLayerInputKeyPathType.LayerInputKeyPathType
public typealias UnpackedPortType = CurrentUnpackedPortType.UnpackedPortType
public typealias StitchTransform = CurrentStitchTransform.StitchTransform
//public typealias StitchComponent = CurrentStitchComponent.StitchComponent


public enum NodeTypeEntity: Equatable, Codable {
    case patch(PatchNodeEntity_V24.PatchNodeEntity)
    case layer(LayerNodeEntity_V24.LayerNodeEntity)
    case group(CanvasNodeEntity_V24.CanvasNodeEntity)
    case component(ComponentEntity)
}

public struct ComponentEntity: Codable, Equatable {
    var id: UUID
    var canvasEntity: CanvasNodeEntity_V24.CanvasNodeEntity
}

public struct NodeEntity: Equatable, Identifiable, Codable {
    public let id: UUID
    public var nodeTypeEntity: NodeTypeEntity
    public let title: String
    
    public init(id: UUID,
                nodeTypeEntity: NodeTypeEntity,
                title: String) {
        self.id = id
        self.nodeTypeEntity = nodeTypeEntity
        self.title = title
    }
}


public struct StitchDocument: Equatable, Codable {
    public var projectId: ProjectId
    public var name: String

    // Preview window
    public let previewWindowSize: CGSize
    public let previewSizeDevice: PreviewSize
    public let previewWindowBackgroundColor: Color

    // Graph positioning data
    public let localPosition: CGPoint
    public let zoomData: CGFloat

    // Node data
    public var nodes: [NodeEntity]
    public var orderedSidebarLayers: [SidebarLayerData]
    public let commentBoxes: [CommentBoxData]

    public let cameraSettings: CameraSettings

    public init(projectId: ProjectId,
         name: String,
         previewWindowSize: CGSize,
         previewSizeDevice: PreviewSize,
         previewWindowBackgroundColor: Color,
         localPosition: CGPoint,
         zoomData: CGFloat,
         nodes: [NodeEntity],
         orderedSidebarLayers: [SidebarLayerData],
         commentBoxes: [CommentBoxData],
         cameraSettings: CameraSettings) {
        self.projectId = projectId
        self.name = name
        self.previewWindowSize = previewWindowSize
        self.previewSizeDevice = previewSizeDevice
        self.previewWindowBackgroundColor = previewWindowBackgroundColor
        self.localPosition = localPosition
        self.zoomData = zoomData
        self.nodes = nodes
        self.orderedSidebarLayers = orderedSidebarLayers
        self.commentBoxes = commentBoxes
        self.cameraSettings = cameraSettings
    }
    
    // MARK: remove `transferRepresentation` from older `StitchDocument` versions
//        static var transferRepresentation: some TransferRepresentation {
//            FileRepresentation(contentType: .stitchDocument,
//                               exporting: Self.exportDocument,
//                               importing: Self.importDocument)
//        }
}

//public enum NodeKind: Codable, Equatable, Hashable {
//    case patch(Patch), layer(Layer), group
//}
