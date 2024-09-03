//
//  LayerNodeEntityUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import StitchSchemaKit

extension LayerInputDataEntity {
    static let empty: Self = .init(inputPort: .values([]),
                                   canvasItem: nil)
}

extension LayerNodeEntity {
    // TODO: can we move this initialzier to StitchSchemaKit ?
    init(nodeId: NodeId,
         layer: Layer,
         positionPort: LayerInputEntity = .empty,
         sizePort: LayerInputEntity = .empty,
         scalePort: LayerInputEntity = .empty,
         anchoringPort: LayerInputEntity = .empty,
         opacityPort: LayerInputEntity = .empty,
         zIndexPort: LayerInputEntity = .empty,
         masksPort: LayerInputEntity = .empty,
         colorPort: LayerInputEntity = .empty,
         rotationXPort: LayerInputEntity = .empty,
         rotationYPort: LayerInputEntity = .empty,
         rotationZPort: LayerInputEntity = .empty,
         lineColorPort: LayerInputEntity = .empty,
         lineWidthPort: LayerInputEntity = .empty,
         blurPort: LayerInputEntity = .empty,
         blendModePort: LayerInputEntity = .empty,
         brightnessPort: LayerInputEntity = .empty,
         colorInvertPort: LayerInputEntity = .empty,
         contrastPort: LayerInputEntity = .empty,
         hueRotationPort: LayerInputEntity = .empty,
         saturationPort: LayerInputEntity = .empty,
         pivotPort: LayerInputEntity = .empty,
         enabledPort: LayerInputEntity = .empty,
         blurRadiusPort: LayerInputEntity = .empty,
         backgroundColorPort: LayerInputEntity = .empty,
         isClippedPort: LayerInputEntity = .empty,
         orientationPort: LayerInputEntity = .empty,
         paddingPort: LayerInputEntity = .empty,
         setupModePort: LayerInputEntity = .empty,
         allAnchorsPort: LayerInputEntity = .empty,
         cameraDirectionPort: LayerInputEntity = .empty,
         isCameraEnabledPort: LayerInputEntity = .empty,
         isShadowsEnabledPort: LayerInputEntity = .empty,
         shapePort: LayerInputEntity = .empty,
         strokePositionPort: LayerInputEntity = .empty,
         strokeWidthPort: LayerInputEntity = .empty,
         strokeColorPort: LayerInputEntity = .empty,
         strokeStartPort: LayerInputEntity = .empty,
         strokeEndPort: LayerInputEntity = .empty,
         strokeLineCapPort: LayerInputEntity = .empty,
         strokeLineJoinPort: LayerInputEntity = .empty,
         coordinateSystemPort: LayerInputEntity = .empty,
         cornerRadiusPort: LayerInputEntity = .empty,
         canvasLineColorPort: LayerInputEntity = .empty,
         canvasLineWidthPort: LayerInputEntity = .empty,
         canvasPositionPort: LayerInputEntity = .empty,
         textPort: LayerInputEntity = .empty,
         fontSizePort: LayerInputEntity = .empty,
         textAlignmentPort: LayerInputEntity = .empty,
         verticalAlignmentPort: LayerInputEntity = .empty,
         textDecorationPort: LayerInputEntity = .empty,
         textFontPort: LayerInputEntity = .empty,
         imagePort: LayerInputEntity = .empty,
         videoPort: LayerInputEntity = .empty,
         fitStylePort: LayerInputEntity = .empty,
         clippedPort: LayerInputEntity = .empty,
         isAnimatingPort: LayerInputEntity = .empty,
         progressIndicatorStylePort: LayerInputEntity = .empty,
         progressPort: LayerInputEntity = .empty,
         model3DPort: LayerInputEntity = .empty,
         mapTypePort: LayerInputEntity = .empty,
         mapLatLongPort: LayerInputEntity = .empty,
         mapSpanPort: LayerInputEntity = .empty,
         isSwitchToggledPort: LayerInputEntity = .empty,
         placeholderTextPort: LayerInputEntity = .empty,
         startColorPort: LayerInputEntity = .empty,
         endColorPort: LayerInputEntity = .empty,
         startAnchorPort: LayerInputEntity = .empty,
         endAnchorPort: LayerInputEntity = .empty,
         centerAnchorPort: LayerInputEntity = .empty,
         startAnglePort: LayerInputEntity = .empty,
         endAnglePort: LayerInputEntity = .empty,
         startRadiusPort: LayerInputEntity = .empty,
         endRadiusPort: LayerInputEntity = .empty,
         shadowColorPort: LayerInputEntity = .empty,
         shadowOpacityPort: LayerInputEntity = .empty,
         shadowRadiusPort: LayerInputEntity = .empty,
         shadowOffsetPort: LayerInputEntity = .empty,
         sfSymbolPort: LayerInputEntity = .empty,
         videoURLPort: LayerInputEntity = .empty,
         volumePort: LayerInputEntity = .empty,
         spacingBetweenGridColumnsPort: LayerInputEntity = .empty,
         spacingBetweenGridRowsPort: LayerInputEntity = .empty,
         itemAlignmentWithinGridCellPort: LayerInputEntity = .empty,
         sizingScenarioPort: LayerInputEntity = .empty,
         widthAxisPort: LayerInputEntity = .empty,
         heightAxisPort: LayerInputEntity = .empty,
         contentModePort: LayerInputEntity = .empty,
         minSizePort: LayerInputEntity = .empty,
         maxSizePort: LayerInputEntity = .empty,
         spacingPort: LayerInputEntity = .empty,
         isPinnedPort: LayerInputEntity = .empty,
         pinToPort: LayerInputEntity = .empty,
         pinAnchorPort: LayerInputEntity = .empty,
         pinOffsetPort: LayerInputEntity = .empty,
//         layerMarginPort: LayerInputEntity = .empty,
//         layerPaddingPort: LayerInputEntity = .empty,
//         offsetInGroupPort: LayerInputEntity = .empty,
         hasSidebarVisibility: Bool,
         layerGroupId: NodeId?,
         isExpandedInSidebar: Bool?) {
        
        let outputsCount = layer.layerGraphNode.rowDefinitions(for: nil).outputs.count
        
        self.init(
            id: nodeId,
            layer: layer,
            outputCanvasPorts: (0..<outputsCount).map { _ in nil }, // just needs to match outputs count
        
        // Required
            positionPort: positionPort,
            sizePort: sizePort,
            scalePort: scalePort,
            anchoringPort: anchoringPort,
            opacityPort: opacityPort,
            zIndexPort: zIndexPort,
        
        // Common
            masksPort: masksPort,
            colorPort: colorPort,
            rotationXPort: rotationXPort,
            rotationYPort: rotationYPort,
            rotationZPort: rotationZPort,
            lineColorPort: lineColorPort,
            lineWidthPort: lineWidthPort,
            blurPort: blurPort,
            blendModePort: blendModePort,
            brightnessPort: brightnessPort,
            colorInvertPort: colorInvertPort,
            contrastPort: contrastPort,
            hueRotationPort: hueRotationPort,
            saturationPort: saturationPort,
            pivotPort: pivotPort,
            enabledPort: enabledPort,
            blurRadiusPort: blurRadiusPort,
            backgroundColorPort: backgroundColorPort,
            isClippedPort: isClippedPort,
            orientationPort: orientationPort,
            paddingPort: paddingPort,
            setupModePort: setupModePort,
            allAnchorsPort: allAnchorsPort,
            cameraDirectionPort: cameraDirectionPort,
            isCameraEnabledPort: isCameraEnabledPort,
            isShadowsEnabledPort: isShadowsEnabledPort,
            shapePort: shapePort,
            strokePositionPort: strokePositionPort,
            strokeWidthPort: strokeWidthPort,
            strokeColorPort: strokeColorPort,
            strokeStartPort: strokeStartPort,
            strokeEndPort: strokeEndPort,
            strokeLineCapPort: strokeLineCapPort,
            strokeLineJoinPort: strokeLineJoinPort,
            coordinateSystemPort: coordinateSystemPort,
            cornerRadiusPort: cornerRadiusPort,
            canvasLineColorPort: canvasLineColorPort,
            canvasLineWidthPort: canvasLineWidthPort,
            canvasPositionPort: canvasPositionPort,
            textPort: textPort,
            fontSizePort: fontSizePort,
            textAlignmentPort: textAlignmentPort,
            verticalAlignmentPort: verticalAlignmentPort,
            textDecorationPort: textDecorationPort,
            textFontPort: textFontPort,
            imagePort: imagePort,
            videoPort: videoPort,
            fitStylePort: fitStylePort,
            clippedPort: clippedPort,
            isAnimatingPort: isAnimatingPort,
            progressIndicatorStylePort: progressIndicatorStylePort,
            progressPort: progressPort,
            model3DPort: model3DPort,
            mapTypePort: mapTypePort,
            mapLatLongPort: mapLatLongPort,
            mapSpanPort: mapSpanPort,
            isSwitchToggledPort: isSwitchToggledPort,
            placeholderTextPort: placeholderTextPort,
            startColorPort: startColorPort,
            endColorPort: endColorPort,
            startAnchorPort: startAnchorPort,
            endAnchorPort: endAnchorPort,
            centerAnchorPort: centerAnchorPort,
            startAnglePort: startAnglePort,
            endAnglePort: endAnglePort,
            startRadiusPort: startRadiusPort,
            endRadiusPort: endRadiusPort,
            
            shadowColorPort: shadowColorPort,
            shadowOpacityPort: shadowOpacityPort,
            shadowRadiusPort: shadowRadiusPort,
            shadowOffsetPort: shadowOffsetPort,
            
            sfSymbolPort: sfSymbolPort,
            
            videoURLPort: videoURLPort,
            volumePort: volumePort,
            
            spacingBetweenGridColumnsPort: spacingBetweenGridColumnsPort,
            spacingBetweenGridRowsPort: spacingBetweenGridRowsPort,
            itemAlignmentWithinGridCellPort: itemAlignmentWithinGridCellPort,
            
            sizingScenarioPort: sizingScenarioPort,
            
            widthAxisPort: widthAxisPort,
            heightAxisPort: heightAxisPort,
            contentModePort: contentModePort,
            minSizePort: minSizePort,
            maxSizePort: maxSizePort,
            spacingPort: spacingPort,
            
            isPinnedPort: isPinnedPort,
            pinToPort: pinToPort,
            pinAnchorPort: pinAnchorPort,
            pinOffsetPort: pinOffsetPort,
            
//            layerPaddingPort: layerPaddingPort, 
//            layerMarginPort: layerMarginPort,
//            offsetInGroupPort: offsetInGroupPort,
            
            hasSidebarVisibility: hasSidebarVisibility,
            layerGroupId: layerGroupId,
            isExpandedInSidebar: isExpandedInSidebar)
    }
}
