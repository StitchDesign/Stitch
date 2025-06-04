//
//  NodeIOPortTypeAI_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/1/25.
//

extension Step_V0.NodeIOPortType {
    func asLLMStepPort() -> Any {
        switch self {
        case .keyPath(let x):
            // Note: StitchAI does not yet support unpacked ports
            // Note 2: see our OpenAI schema for list of possible `LayerPorts`
            return x.layerInput.asLLMStepPort
        case .portIndex(let x):
            // Return the integer directly instead of converting to string
            return x
        }
    }
}

extension Step_V0.LayerInputPort {
    var asLLMStepPort: String {
        self.label(useShortLabel: true)
    }
}
