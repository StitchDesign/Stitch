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
public typealias NodeEntity = CurrentNodeEntity.NodeEntity
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
public typealias StitchDocument = CurrentStitchDocument.StitchDocument
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
public typealias NodeTypeEntity = CurrentNodeTypeEntity.NodeTypeEntity
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
public typealias StitchComponent = CurrentStitchComponent.StitchComponent
public typealias ComponentEntity = CurrentComponentEntity.ComponentEntity
public typealias GraphEntity = CurrentGraphEntity.GraphEntity
public typealias GraphSaveLocation = CurrentGraphSaveLocation.GraphSaveLocation
public typealias GraphDocumentPath = CurrentGraphDocumentPath.GraphDocumentPath
public typealias StitchSystem = CurrentStitchSystem.StitchSystem
public typealias StitchSystemType = CurrentStitchSystemType.StitchSystemType
public typealias DeviceAppearance = CurrentDeviceAppearance.DeviceAppearance
public typealias MaterialThickness = CurrentMaterialThickness.MaterialThickness
public typealias JavaScriptNodeSettings = CurrentJavaScriptNodeSettings.JavaScriptNodeSettings
public typealias JavaScriptPortDefinition = CurrentJavaScriptPortDefinition.JavaScriptPortDefinition
public typealias KeyboardType = CurrentKeyboardType.KeyboardType
public typealias PatchOrLayer = CurrentPatchOrLayer.PatchOrLayer
public typealias NodeKindDescribable = CurrentNodeKindDescribable.NodeKindDescribable
public typealias StitchAINodeKindDescription = CurrentStitchAINodeKindDescription.StitchAINodeKindDescription

public struct StitchDocumentVersion: StitchSchemaVersionType {
    public typealias NewestVersionType = StitchDocument
    
    public var version: StitchSchemaVersion
    
    public init(version: StitchSchemaVersion) {
        self.version = version
    }
}

public struct PortValueVersion: StitchSchemaVersionType {
    public typealias NewestVersionType = PortValue
    
    public var version: StitchSchemaVersion
    
    public init(version: StitchSchemaVersion) {
        self.version = version
    }
}

public struct NodeTypeVersion: StitchSchemaVersionType {
    public typealias NewestVersionType = NodeType
    
    public var version: StitchSchemaVersion
    
    public init(version: StitchSchemaVersion) {
        self.version = version
    }
}

public struct StitchSystemVersion: StitchSchemaVersionType {
    public typealias NewestVersionType = StitchSystem
    
    public var version: StitchSchemaVersion
    
    public init(version: StitchSchemaVersion) {
        self.version = version
    }
}

public struct StitchComponentVersion: StitchSchemaVersionType {
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
        case ._V25:
            return StitchDocument_V25.StitchDocument.self
        case ._V26:
            return StitchDocument_V26.StitchDocument.self
        case ._V27:
            return StitchDocument_V27.StitchDocument.self
        case ._V28:
            return StitchDocument_V28.StitchDocument.self
        case ._V29:
            return StitchDocument_V29.StitchDocument.self
        case ._V30:
            return StitchDocument_V30.StitchDocument.self
        case ._V31:
            return StitchDocument_V31.StitchDocument.self
        case ._V32:
            return StitchDocument_V32.StitchDocument.self
        }
    }
}

extension PortValueVersion {
    public static func getCodableType(from version: StitchSchemaVersion) -> any StitchVersionedCodable.Type {
        switch version {
        case ._V1:
            return PortValue_V1.PortValue.self
        case ._V2:
            return PortValue_V2.PortValue.self
        case ._V3:
            return PortValue_V3.PortValue.self
        case ._V4:
            return PortValue_V4.PortValue.self
        case ._V5:
            return PortValue_V5.PortValue.self
        case ._V6:
            return PortValue_V6.PortValue.self
        case ._V7:
            return PortValue_V7.PortValue.self
        case ._V8:
            return PortValue_V8.PortValue.self
        case ._V9:
            return PortValue_V9.PortValue.self
        case ._V10:
            return PortValue_V10.PortValue.self
        case ._V11:
            return PortValue_V11.PortValue.self
        case ._V12:
            return PortValue_V12.PortValue.self
        case ._V13:
            return PortValue_V13.PortValue.self
        case ._V14:
            return PortValue_V14.PortValue.self
        case ._V15:
            return PortValue_V15.PortValue.self
        case ._V16:
            return PortValue_V16.PortValue.self
        case ._V17:
            return PortValue_V17.PortValue.self
        case ._V18:
            return PortValue_V18.PortValue.self
        case ._V19:
            return PortValue_V19.PortValue.self
        case ._V20:
            return PortValue_V20.PortValue.self
        case ._V21:
            return PortValue_V21.PortValue.self
        case ._V22:
            return PortValue_V22.PortValue.self
        case ._V23:
            return PortValue_V23.PortValue.self
        case ._V24:
            return PortValue_V24.PortValue.self
        case ._V25:
            return PortValue_V25.PortValue.self
        case ._V26:
            return PortValue_V26.PortValue.self
        case ._V27:
            return PortValue_V27.PortValue.self
        case ._V28:
            return PortValue_V28.PortValue.self
        case ._V29:
            return PortValue_V29.PortValue.self
        case ._V30:
            return PortValue_V30.PortValue.self
        case ._V31:
            return PortValue_V31.PortValue.self
        case ._V32:
            return PortValue_V32.PortValue.self
        }
    }
}

extension NodeTypeVersion {
    public static func getCodableType(from version: StitchSchemaVersion) -> any StitchVersionedCodable.Type {
        switch version {
        case ._V1:
            return UserVisibleType_V1.UserVisibleType.self
        case ._V2:
            return UserVisibleType_V2.UserVisibleType.self
        case ._V3:
            return UserVisibleType_V3.UserVisibleType.self
        case ._V4:
            return UserVisibleType_V4.UserVisibleType.self
        case ._V5:
            return UserVisibleType_V5.UserVisibleType.self
        case ._V6:
            return UserVisibleType_V6.UserVisibleType.self
        case ._V7:
            return UserVisibleType_V7.UserVisibleType.self
        case ._V8:
            return UserVisibleType_V8.UserVisibleType.self
        case ._V9:
            return UserVisibleType_V9.UserVisibleType.self
        case ._V10:
            return UserVisibleType_V10.UserVisibleType.self
        case ._V11:
            return UserVisibleType_V11.UserVisibleType.self
        case ._V12:
            return UserVisibleType_V12.UserVisibleType.self
        case ._V13:
            return UserVisibleType_V13.UserVisibleType.self
        case ._V14:
            return UserVisibleType_V14.UserVisibleType.self
        case ._V15:
            return UserVisibleType_V15.UserVisibleType.self
        case ._V16:
            return UserVisibleType_V16.UserVisibleType.self
        case ._V17:
            return UserVisibleType_V17.UserVisibleType.self
        case ._V18:
            return UserVisibleType_V18.UserVisibleType.self
        case ._V19:
            return UserVisibleType_V19.UserVisibleType.self
        case ._V20:
            return UserVisibleType_V20.UserVisibleType.self
        case ._V21:
            return UserVisibleType_V21.UserVisibleType.self
        case ._V22:
            return UserVisibleType_V22.UserVisibleType.self
        case ._V23:
            return UserVisibleType_V23.UserVisibleType.self
        case ._V24:
            return UserVisibleType_V24.UserVisibleType.self
        case ._V25:
            return UserVisibleType_V25.UserVisibleType.self
        case ._V26:
            return UserVisibleType_V26.UserVisibleType.self
        case ._V27:
            return UserVisibleType_V27.UserVisibleType.self
        case ._V28:
            return UserVisibleType_V28.UserVisibleType.self
        case ._V29:
            return UserVisibleType_V29.UserVisibleType.self
        case ._V30:
            return UserVisibleType_V30.UserVisibleType.self
        case ._V31:
            return UserVisibleType_V31.UserVisibleType.self
        case ._V32:
            return UserVisibleType_V32.UserVisibleType.self
        }
    }
}

extension StitchSystemVersion {
    public static func getCodableType(from version: StitchSchemaVersion) -> any StitchVersionedCodable.Type {
        switch version {
        case ._V1, ._V2, ._V3, ._V4, ._V5, ._V6, ._V7, ._V8, ._V9, ._V10, ._V11, ._V12, ._V13, ._V14, ._V15, ._V16, ._V17, ._V18, ._V19, ._V20, ._V21, ._V22, ._V23, ._V24:
            fatalError("No StitchSystem version expected before v24.")
            
        case ._V25:
            return StitchSystem_V25.StitchSystem.self
        case ._V26:
            return StitchSystem_V26.StitchSystem.self
        case ._V27:
            return StitchSystem_V27.StitchSystem.self
        case ._V28:
            return StitchSystem_V28.StitchSystem.self
        case ._V29:
            return StitchSystem_V29.StitchSystem.self
        case ._V30:
            return StitchSystem_V30.StitchSystem.self
        case ._V31:
            return StitchSystem_V31.StitchSystem.self
        case ._V32:
            return StitchSystem_V32.StitchSystem.self
        }
    }
}

extension StitchComponentVersion {
    public static func getCodableType(from version: StitchSchemaVersion) -> any StitchVersionedCodable.Type {
        switch version {
        case ._V1, ._V2, ._V3, ._V4, ._V5, ._V6, ._V7, ._V8, ._V9, ._V10, ._V11, ._V12, ._V13, ._V14, ._V15, ._V16, ._V17, ._V18, ._V19, ._V20, ._V21, ._V22, ._V23, ._V24:
            fatalError("No StitchComponent version expected before v24.")
            
        case ._V25:
            return StitchComponent_V25.StitchComponent.self
        case ._V26:
            return StitchComponent_V26.StitchComponent.self
        case ._V27:
            return StitchComponent_V27.StitchComponent.self
        case ._V28:
            return StitchComponent_V28.StitchComponent.self
        case ._V29:
            return StitchComponent_V29.StitchComponent.self
        case ._V30:
            return StitchComponent_V30.StitchComponent.self
        case ._V31:
            return StitchComponent_V31.StitchComponent.self
        case ._V32:
            return StitchComponent_V32.StitchComponent.self
        }
    }
}

