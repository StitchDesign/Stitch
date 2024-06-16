//
//  PulseReversionUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import StitchSchemaKit

extension PortValuesList {
    func getPulseReversionEffects(nodeId: NodeId,
                                  graphTime: TimeInterval) -> SideEffects {
        self.enumerated()
            .flatMap { portId, values in
                values.getPulseReversionEffects(nodeId: nodeId,
                                                portId: portId,
                                                graphTime: graphTime)
            }
    }
}

extension PortValues {
    func getPulseReversionEffects(nodeId: NodeId,
                                  portId: Int,
                                  graphTime: TimeInterval) -> SideEffects {
        self.flatMap {
            $0.getPulseReversionEffects(nodeId: nodeId,
                                        portId: portId,
                                        graphTime: graphTime)
        }
    }
}

extension PortValue {
    func getPulseReversionEffects(nodeId: NodeId,
                                  portId: Int,
                                  graphTime: TimeInterval) -> SideEffects {
        if let lastTimePulsed = self.getPulse,
           lastTimePulsed.shouldPulse(graphTime) {
            let pulsedIndex = NodeIOCoordinate(portId: portId,
                                               nodeId: nodeId)
            return getPostPulseEffects(.output(pulsedIndex))
        }
        
        return []
    }
}
