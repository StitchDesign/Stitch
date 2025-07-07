//
//  UnpackedValueCoercer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/24.
//

import Foundation
import StitchSchemaKit

// MARK: - organizes logic for unpacked port observers for layer inspector

//extension [PortValue] {
//    func unpackedPositionCoercer() -> PortValue {
//        guard self.count == 2 else {
//            fatalErrorIfDebug()
//            return .position(.zero)
//        }
//        
//        return .position(.init(x: self[safe: 0]?.getNumber ?? .zero,
//                               y: self[safe: 1]?.getNumber ?? .zero))
//    }
//}


// See also `PortValue.unpack: PortValue -> PortValues?`
extension PortValues {
    func pack(type: NodeType) -> PortValue? {
        
        let count = self.count
        
        switch type {
        case .size:
#if !DEV_DEBUG
            assertInDebug(count == 2)
#endif
            return .size(.init(width: self[safe: 0]?.getLayerDimension ?? .number(.zero),
                               height: self[safe: 1]?.getLayerDimension ?? .number(.zero)))
            
        case .position:
#if !DEV_DEBUG
            assertInDebug(count == 2)
#endif
            return .position(.init(x: self[safe: 0]?.getNumber ?? .zero,
                                   y: self[safe: 1]?.getNumber ?? .zero))
            
        case .point3D:
#if !DEV_DEBUG
            assertInDebug(count == 3)
#endif
            return .point3D(.init(x: self[safe: 0]?.getNumber ?? .zero,
                                  y: self[safe: 1]?.getNumber ?? .zero,
                                  z: self[safe: 2]?.getNumber ?? .zero))
            
        case .point4D:
#if !DEV_DEBUG
            assertInDebug(count == 4)
#endif
            return .point4D(.init(x: self[safe: 0]?.getNumber ?? .zero,
                                  y: self[safe: 1]?.getNumber ?? .zero,
                                  z: self[safe: 2]?.getNumber ?? .zero,
                                  w: self[safe: 3]?.getNumber ?? .zero))
            
        case .padding:
#if !DEV_DEBUG
            assertInDebug(count == 4)
#endif
            return PortValue.padding(.init(top: self[safe: 0]?.getNumber ?? .zero,
                                           right: self[safe: 1]?.getNumber ?? .zero,
                                           bottom: self[safe: 2]?.getNumber ?? .zero,
                                           left: self[safe: 3]?.getNumber ?? .zero))
            
        case .transform:
#if !DEV_DEBUG
            assertInDebug(count == 9)
#endif
            return PortValue.transform(.init(positionX: self[safe: 0]?.getNumber ?? .zero,
                                             positionY: self[safe: 1]?.getNumber ?? .zero,
                                             positionZ: self[safe: 2]?.getNumber ?? .zero,
                                             scaleX: self[safe: 3]?.getNumber ?? .zero,
                                             scaleY: self[safe: 4]?.getNumber ?? .zero,
                                             scaleZ: self[safe: 5]?.getNumber ?? .zero,
                                             rotationX: self[safe: 6]?.getNumber ?? .zero,
                                             rotationY: self[safe: 7]?.getNumber ?? .zero,
                                             rotationZ: self[safe: 8]?.getNumber ?? .zero))
            
            
        default:
            // log("LayerInputPort: pack")
            return nil
        }
    }
}
