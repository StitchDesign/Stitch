//
//  StitchEntityType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/16/25.
//

import Foundation
import StitchSchemaKit
import RealityKit
import SceneKit
import SwiftUI

enum StitchEntityType {
    case importedMedia(URL)
    case box
    case sphere
    case cylinder
    case cone
}

/// Convenience struct for unpacking relevant 3D input data in helper functions.
struct Model3DInputData {
    let size3D: Point3D
    let radius3D: CGFloat
    let height3D: CGFloat
    let cornerRadius: CGFloat
    let color: Color
    let isMetallic: Bool
    
    @MainActor
    init(layerViewModel: LayerViewModel) {
        self.size3D = layerViewModel.size3D.getPoint3D ?? .zero
        self.radius3D = layerViewModel.radius3D.getNumber ?? .zero
        self.height3D = layerViewModel.height3D.getNumber ?? .zero
        self.cornerRadius = layerViewModel.cornerRadius.getNumber ?? .zero
        self.color = layerViewModel.color.getColor ?? .red
        self.isMetallic = layerViewModel.isMetallic.getBool ?? false
    }
}

extension StitchEntityType {
    var isImportMedia: Bool {
        switch self {
        case .importedMedia:
            return true
        default:
            return false
        }
    }
    
    @MainActor
    func createMeshResource(layerViewModel: LayerViewModel) -> MeshResource? {
        let data = Model3DInputData(layerViewModel: layerViewModel)
        
        switch self {
        case .importedMedia:
            // Do nothing
            return nil
            
        case .box:
            return MeshResource.generateBox(width: Float(data.size3D.x),
                                            height: Float(data.size3D.y),
                                            depth: Float(data.size3D.z),
                                            cornerRadius: Float(data.cornerRadius))
            
        case .sphere:
            return MeshResource.generateSphere(radius: Float(data.radius3D))
            
        case .cone:
            return MeshResource.generateCone(height: Float(data.height3D),
                                             radius: Float(data.radius3D))
            
        case .cylinder:
            return MeshResource.generateCylinder(height: Float(data.height3D),
                                                 radius: Float(data.radius3D))
        }
    }
    
    @MainActor func createSCNGeometry(layerViewModel: LayerViewModel) -> SCNGeometry? {
        let data = Model3DInputData(layerViewModel: layerViewModel)
        
        switch self {
        case .importedMedia:
            // do nothing
            return nil
        
        case .box:
            return SCNBox(width: data.size3D.x,
                          height: data.size3D.y,
                          length: data.size3D.z,
                          chamferRadius: data.cornerRadius)
            
        case .sphere:
            return SCNSphere(radius: data.radius3D)
            
        case .cone:
            return SCNCone(topRadius: .zero,
                           bottomRadius: data.radius3D,
                           height: data.height3D)
            
        case .cylinder:
            return SCNCylinder(radius: data.radius3D,
                               height: data.height3D)
        }
    }
    
    @MainActor func updateSCNScene(from scene: SCNScene,
                                   layerViewModel: LayerViewModel) {
        guard let geometry = scene.rootNode.childNodes.compactMap({ $0.geometry }).first else {
            fatalErrorIfDebug()
            return
        }
        
        let data = Model3DInputData(layerViewModel: layerViewModel)
        
        switch self {
        case .importedMedia:
            // do nothing
            return
        
        case .box:
            guard let box = geometry as? SCNBox else {
                fatalErrorIfDebug()
                return
            }
            
            box.width = data.size3D.x
            box.height = data.size3D.y
            box.length = data.size3D.z
            box.chamferRadius = data.cornerRadius
            
        case .sphere:
            guard let sphere = geometry as? SCNSphere else {
                fatalErrorIfDebug()
                return
            }
            
            sphere.radius = data.radius3D
            
        case .cone:
            guard let cone = geometry as? SCNCone else {
                fatalErrorIfDebug()
                return
            }
            
            cone.bottomRadius = data.radius3D
            cone.height = data.height3D
            
        case .cylinder:
            guard let cylinder = geometry as? SCNCylinder else {
                fatalErrorIfDebug()
                return
            }
            
            cylinder.radius = data.radius3D
            cylinder.height = data.height3D
        }
        
        Self.commonSCNSceneUpdates(geometry: geometry,
                                   layerViewModel: layerViewModel)
    }
    
    @MainActor
    private static func commonSCNSceneUpdates(geometry: SCNGeometry,
                                       layerViewModel: LayerViewModel) {
        geometry.firstMaterial?.diffuse.contents = layerViewModel.color.getColor?.toUIColor ?? .red
    }
}
