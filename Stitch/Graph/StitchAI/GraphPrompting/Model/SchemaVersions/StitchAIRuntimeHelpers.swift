//
//  StitchAIRuntimeHelpers.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/25.
//

// MARK: - comment or uncomment code below when runtime versions equate or differ from Stitch AI schema types.

//extension UserVisibleType {
//    var portValueTypeForStitchAI: Decodable.Type? {
//        do {
//            let convertedType = try self.convert(to: StitchAINodeType.self)
//            return convertedType.portValueTypeForStitchAI
//        } catch {
//            fatalErrorIfDebug("portValueTypeForStitchAI error: \(error)")
//            return nil
//        }
//    }
//    
//    func coerceToPortValueForStitchAI(from anyValue: Any) throws -> PortValue {
//        let convertedType = try self.convert(to: StitchAINodeType.self)
//        let value = try convertedType.coerceToPortValueForStitchAI(from: anyValue)
//        let migratedValue = try value.migrate()
//        return migratedValue
//    }
//    
//    // given a user-visible node type, get its corresponding PortValue
//    var defaultPortValue: PortValue {
//        //    log("nodeTypeToPortValue: nodeType: \(nodeType)")
//        switch self {
//        case .string:
//            return stringDefault
//        case .number:
//            return numberDefaultFalse
//        case .layerDimension:
//            return layerDimensionDefaultFalse
//        case .bool:
//            return boolDefaultFalse
//        case .color:
//            return colorDefaultFalse
//        // NOT CORRECT FOR size, position, point3D etc.
//        // because eg position becomes
//        case .size:
//            return defaultSizeFalse
//        case .position:
//            return defaultPositionFalse
//        case .point3D:
//            return point3DDefaultFalse
//        case .point4D:
//            return point4DDefaultFalse
//            //TODO: Change
//        case .transform:
//            return defaultTransformAnchor
//        case .pulse:
//            return pulseDefaultFalse
//        case .media:
//            return mediaDefault
//        case .json:
//            return jsonDefault
//        case .none:
//            return .none
//        case .anchoring:
//            return .anchoring(.defaultAnchoring)
//        case .cameraDirection:
//            return cameraDirectionDefault
//        case .interactionId:
//            return interactionIdDefault
//        case .scrollMode:
//            return scrollModeDefault
//        case .textAlignment:
//            return defaultTextAlignment
//        case .textVerticalAlignment:
//            return defaultTextVerticalAlignment
//        case .fitStyle:
//            return .fitStyle(.defaultMediaFitStyle)
//        case .animationCurve:
//            return .animationCurve(defaultAnimationCurve)
//        case .lightType:
//            return .lightType(defaultLightType)
//        case .layerStroke:
//            return .layerStroke(.defaultStroke)
//        case .textTransform:
//            return .textTransform(.defaultTransform)
//        case .dateAndTimeFormat:
//            return .dateAndTimeFormat(.defaultFormat)
//        case .shape:
//            return .shape(.triangleShapePatchNodeDefault)
//        case .scrollJumpStyle:
//            return .scrollJumpStyle(.scrollJumpStyleDefault)
//        case .scrollDecelerationRate:
//            return .scrollDecelerationRate(.scrollDecelerationRateDefault)
//        case .plane:
//            return .plane(.any)
//        case .networkRequestType:
//            return .networkRequestType(.get)
//        case .delayStyle:
//            return .delayStyle(.always)
//        case .shapeCoordinates:
//            return .shapeCoordinates(.relative)
//        case .shapeCommand:
//            return .shapeCommand(.defaultFalseShapeCommand)
//        case .shapeCommandType:
//            return .shapeCommandType(.defaultFalseShapeCommandType)
//        case .orientation:
//            return .orientation(.defaultOrientation)
//        case .cameraOrientation:
//            return .cameraOrientation(.landscapeRight)
//        case .deviceOrientation:
//            return .deviceOrientation(.defaultDeviceOrientation)
//        case .vnImageCropOption:
//            return .vnImageCropOption(.centerCrop).defaultFalseValue
//        case .textDecoration:
//            return .textDecoration(.defaultLayerTextDecoration)
//        case .textFont:
//            return .textFont(.defaultStitchFont)
//        case .blendMode:
//            return .blendMode(.defaultBlendMode)
//        case .mapType:
//            return .mapType(.defaultMapType)
//        case .mobileHapticStyle:
//            return .mobileHapticStyle(.defaultMobileHapticStyle)
//        case .progressIndicatorStyle:
//            return .progressIndicatorStyle(.circular)
//        case .strokeLineCap:
//            return .strokeLineCap(.defaultStrokeLineCap)
//        case .strokeLineJoin:
//            return .strokeLineJoin(.defaultStrokeLineJoin)
//        case .contentMode:
//            return .contentMode(.defaultContentMode)
//        case .spacing:
//            return .spacing(.defaultStitchSpacing)
//        case .padding:
//            return .padding(.defaultPadding)
//        case .sizingScenario:
//            return .sizingScenario(.defaultSizingScenario)
//        case .pinToId:
//            return .pinTo(.defaultPinToId)
//        case .deviceAppearance:
//            return .deviceAppearance(.defaultDeviceAppearance)
//        case .materialThickness:
//            return .materialThickness(.defaultMaterialThickness)
//        case .anchorEntity:
//            return .anchorEntity(nil)
//        case .keyboardType:
//            return KeyboardType.defaultKeyboardTypePortValue
//        }
//}
//
//extension PortValue {
//    var anyCodable: (any Codable)? {
//        do {
//            let migratedPortValue = try self.convert(to: CurrentStep.PortValue.self)
//            return migratedPortValue.anyCodable
//        } catch {
//            fatalErrorIfDebug("PortValue.anyCodable error: \(error)")
//            return nil
//        }
//    }
//}

//extension LayerDimension {
//    // TODO: restrict edits to the logic described in `getFilteredChoices` in `InputValueView`
//    static func fromUserEdit(edit: String) -> LayerDimension? {
//        if edit == LayerDimension.AUTO_SIZE_STRING {
//            return .auto
//        } else if edit == LayerDimension.FILL_SIZE_STRING {
//            return .fill
//        } else if edit == LayerDimension.HUG_SIZE_STRING {
//            return .hug
//        } else if let n = parsePercentage(edit) {
//            return .parentPercent(n)
//        } else if let n = toNumber(edit) {
//            return .number(CGFloat(n))
//        } else {
//            return nil
//        }
//    }
//}

//extension CurrentStep.PortValue {
//    var getInteractionId: NodeId? {
//        switch self {
//        case .assignedLayer(let x): return x?.id
//        default: return nil
//        }
//    }
//}
