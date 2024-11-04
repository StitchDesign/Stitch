//
//  PulseReversionUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import StitchSchemaKit

//extension PortValuesList {
//    func getPulseReversionEffects(nodeId: NodeId,
//                                  graphTime: TimeInterval) -> SideEffects {
//        self.enumerated()
//            .flatMap { portId, values in
//                values.getPulseReversionEffects(nodeId: nodeId,
//                                                portId: portId,
//                                                graphTime: graphTime)
//            }
//    }
//}

extension PortValues {
    func getPulseReversionEffects(id: NodeIOCoordinate,
                                  graphTime: TimeInterval) -> SideEffects {
        self.flatMap {
            $0.getPulseReversionEffects(id: id,
                                        graphTime: graphTime)
        }
    }
}

extension PortValue {
    func getPulseReversionEffects(id: NodeIOCoordinate,
                                  graphTime: TimeInterval) -> SideEffects {
        if let lastTimePulsed = self.getPulse,
           lastTimePulsed.shouldPulse(graphTime) {
            return getPostPulseEffects(.output(id))
        }
        
        return []
    }
}
