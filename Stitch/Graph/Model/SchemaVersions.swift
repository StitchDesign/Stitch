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
public typealias NodeEntity = Stitch.NodeEntity_V24.NodeEntity
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
public typealias StitchDocument = Stitch.StitchDocument_V24.StitchDocument
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
public typealias StitchComponent = StitchComponent_V24.StitchComponent // CurrentStitchComponent.StitchComponent


// TODO: move
public struct StitchDocumentVersion: StitchSchemaVersionType {
    public typealias NewestVersionType = StitchDocument
    
    public var version: StitchSchemaVersion
    
    public init(version: StitchSchemaVersion) {
        self.version = version
    }
}

public struct StitchComonentVersion: StitchSchemaVersionType {
    public typealias NewestVersionType = StitchComponent
    
    public var version: StitchSchemaVersion
    
    public init(version: StitchSchemaVersion) {
        self.version = version
    }
}

extension StitchDocumentVersion {
    public static func getCodableType(from version: StitchSchemaVersion) -> any StitchVersionedCodable.Type {
        switch version {
        case ._V1:
            return StitchDocument_V1.StitchDocument.self
        case ._V2:
            return StitchDocument_V2.StitchDocument.self
        case ._V3:
            return StitchDocument_V3.StitchDocument.self
        case ._V4:
            return StitchDocument_V4.StitchDocument.self
        case ._V5:
            return StitchDocument_V5.StitchDocument.self
        case ._V6:
            return StitchDocument_V6.StitchDocument.self
        case ._V7:
            return StitchDocument_V7.StitchDocument.self
        case ._V8:
            return StitchDocument_V8.StitchDocument.self
        case ._V9:
            return StitchDocument_V9.StitchDocument.self
        case ._V10:
            return StitchDocument_V10.StitchDocument.self
        case ._V11:
            return StitchDocument_V11.StitchDocument.self
        case ._V12:
            return StitchDocument_V12.StitchDocument.self
        case ._V13:
            return StitchDocument_V13.StitchDocument.self
        case ._V14:
            return StitchDocument_V14.StitchDocument.self
        case ._V15:
            return StitchDocument_V15.StitchDocument.self
        case ._V16:
            return StitchDocument_V16.StitchDocument.self
        case ._V17:
            return StitchDocument_V17.StitchDocument.self
        case ._V18:
            return StitchDocument_V18.StitchDocument.self
        case ._V19:
            return StitchDocument_V19.StitchDocument.self
        case ._V20:
            return StitchDocument_V20.StitchDocument.self
        case ._V21:
            return StitchDocument_V21.StitchDocument.self
        case ._V22:
            return StitchDocument_V22.StitchDocument.self
        case ._V23:
            return StitchDocument_V23.StitchDocument.self
        case ._V24:
            return StitchDocument_V24.StitchDocument.self
        }
    }
}

extension StitchComonentVersion {
    public static func getCodableType(from version: StitchSchemaVersion) -> any StitchVersionedCodable.Type {
        switch version {
        case ._V1, ._V2, ._V3, ._V4, ._V5, ._V6, ._V7, ._V8, ._V9, ._V10, ._V11, ._V12, ._V13, ._V14, ._V15, ._V16, ._V17, ._V18, ._V19, ._V20, ._V21, ._V22, ._V23:
            fatalError("No StitchComponent version expected before v24.")
            
        case ._V24:
            return StitchComponent_V24.StitchComponent.self
        }
    }
}


public enum NodeTypeEntity: Equatable, Codable {
    case patch(PatchNodeEntity_V24.PatchNodeEntity)
    case layer(LayerNodeEntity_V24.LayerNodeEntity)
    case group(CanvasNodeEntity_V24.CanvasNodeEntity)
    case component(ComponentEntity)
}

public struct ComponentEntity: Codable, Equatable {
    let componentId: UUID
    var inputs: [NodeConnectionType_V24.NodeConnectionType]
    var canvasEntity: CanvasNodeEntity_V24.CanvasNodeEntity
}

public enum NodeEntity_V24: StitchSchemaVersionable {
    public static let version = StitchSchemaVersion._V24
    
    public struct NodeEntity: StitchVersionedCodable, Equatable, Identifiable {
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
    
        public init(previousInstance: Self) {
            fatalError()
        }
    }
}

// TODO: move to SSK
public enum StitchComponent_V24: StitchSchemaVersionable {
    public static let version = StitchSchemaVersion._V24
    
    public struct StitchComponent: StitchVersionedCodable, Equatable, Sendable {
//        public var id: UUID
        
        // Share location, saved here due to static helpers for sharing
        public var saveLocation: GraphSaveLocation
        public var isPublished: Bool
        
        public var graph: GraphEntity
//        public let lastModifiedDate: Date
//        public let version: Int
        
        public init(
            //            id: UUID,
            saveLocation: GraphSaveLocation,
            isPublished: Bool,
            graph: GraphEntity) {
                //                    lastModifiedDate: Date,
                //                    version: Int) {
                //            self.id = id
                self.saveLocation = saveLocation
                self.isPublished = isPublished
                self.graph = graph
                //            self.lastModifiedDate = lastModifiedDate
                //            self.version = version
            }
        
        public init(previousInstance: Self) {
            fatalError()
        }
    }
}

public struct GraphEntity: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var nodes: [NodeEntity]
    public var orderedSidebarLayers: [SidebarLayerData]
    public let commentBoxes: [CommentBoxData]
    
    init(id: UUID,
         name: String,
         nodes: [NodeEntity],
         orderedSidebarLayers: [SidebarLayerData],
         commentBoxes: [CommentBoxData]) {
        self.id = id
        self.name = name
        self.nodes = nodes
        self.orderedSidebarLayers = orderedSidebarLayers
        self.commentBoxes = commentBoxes
    }
}

public enum StitchDocument_V24: StitchSchemaVersionable {
    public static let version = StitchSchemaVersion._V24
    
    public struct StitchDocument: StitchVersionedCodable, Equatable, Sendable {
        // Node data
        public var graph: GraphEntity

        // Preview window
        public let previewWindowSize: CGSize
        public let previewSizeDevice: PreviewSize
        public let previewWindowBackgroundColor: Color
        
        // Graph positioning data
        public let localPosition: CGPoint
        public let zoomData: CGFloat
        
        public let cameraSettings: CameraSettings
        
        public init(graph: GraphEntity,
                    previewWindowSize: CGSize,
                    previewSizeDevice: PreviewSize,
                    previewWindowBackgroundColor: Color,
                    localPosition: CGPoint,
                    zoomData: CGFloat,
                    cameraSettings: CameraSettings) {
            self.graph = graph
            self.previewWindowSize = previewWindowSize
            self.previewSizeDevice = previewSizeDevice
            self.previewWindowBackgroundColor = previewWindowBackgroundColor
            self.localPosition = localPosition
            self.zoomData = zoomData
            self.cameraSettings = cameraSettings
        }
        
        public init(previousInstance: Self) {
            fatalError()
        }
        
        // MARK: remove `transferRepresentation` from older `StitchDocument` versions
        //        static var transferRepresentation: some TransferRepresentation {
        //            FileRepresentation(contentType: .stitchDocument,
        //                               exporting: Self.exportDocument,
        //                               importing: Self.importDocument)
        //        }
    }
}

//public enum NodeKind: Codable, Equatable, Hashable {
//    case patch(Patch), layer(Layer), group
//}
