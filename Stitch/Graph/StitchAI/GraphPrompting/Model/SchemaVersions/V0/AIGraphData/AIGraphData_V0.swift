//
//  AIGraphData_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/15/25.
//

import StitchSchemaKit
import SwiftUI

enum AIGraphData_V0 {
    struct CodeCreatorParams: Codable {
        // String because layer data isn't supported for structured params given nesting
        let layer_data_list: String
        let patch_data: PatchData
    }
    
    struct GraphData: Codable {
        let layer_data_list: [LayerData]
        let patch_data: PatchData
    }
    
    struct GraphDataSchema: Encodable {
        // MARK: string because recursive schemas aren't supported and we'll have mapping replace this
        let layer_data_list = OpenAISchema(type: .string)
        let patch_data = AIPatchBuilderResponseFormat_V0
            .PatchBuilderStructuredOutputsDefinitions
            .PatchData
    }
    
    struct PatchData: Codable {
        let javascript_patches: [AIGraphData_V0.JsPatchNode]
        let native_patches: [AIGraphData_V0.NativePatchNode]
        let native_patch_value_type_settings: [AIGraphData_V0.NativePatchNodeValueTypeSetting]
        let patch_connections: [PatchConnection]
        let custom_patch_input_values: [CustomPatchInputValue]
    
        // All connections are captured by patch data regardless of patch or layer
        let layer_connections: [LayerConnection]
    }

    struct LayerData {
        var node_id: String
        var suggested_title: String?
        let node_name: StitchAIPatchOrLayer
        var children: [LayerData]?
        var custom_layer_input_values: [LayerPortDerivation] = []
    }
    
    struct JsPatchNode: Codable {
        let node_id: String
        let javascript_source_code: String
        let suggested_title: String
        let input_definitions: [JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI]
        let output_definitions: [JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI]
    }
    
    struct NativePatchNode: Codable {
        let node_id: String
        let node_name: StitchAIPatchOrLayer
    }
    
    struct NativePatchNodeValueTypeSetting: Codable {
        let node_id: String
        let value_type: StitchAINodeType
    }
    
    struct PatchConnection: Codable {
        let src_port: NodeIndexedCoordinate   // source node's output port
        let dest_port: NodeIndexedCoordinate  // destination patch node's input port
    }
    
    struct LayerConnection: Codable {
        let src_port: NodeIndexedCoordinate   // source node's output port
        let dest_port: LayerInputCoordinate   // destination patch node's input port
    }
    
    struct LayerInputCoordinate: Codable {
        var layer_id: String
        let input_port_type: LayerInputType
    }

    struct NodeIndexedCoordinate: Codable, Hashable {
        let node_id: String
        let port_index: Int
    }
    
    struct CustomPatchInputValue: Codable {
        let patch_input_coordinate: NodeIndexedCoordinate
        let value: any (Codable & Sendable)
        let value_type: StitchAINodeType
    }
    
//    struct CustomLayerInputValue {
//        var layer_input_coordinate: LayerInputCoordinate
//        let value: any (Codable & Sendable)
//        let value_type: StitchAINodeType
//    }
    
    struct AILayerInputPort {
        var value: AIGraphData_V0.LayerInputPort
    }
    
    // TODO: remove wrapper types
    
    struct StitchAIPatchOrLayer: StitchAIStringConvertable {
        var value: AIGraphData_V0.PatchOrLayer
    }
    
    struct StitchAINodeType: StitchAIStringConvertable {
        var value: AIGraphData_V0.NodeType
    }
    
    public enum PatchOrLayer: Hashable, Equatable {
        case patch(AIGraphData_V0.Patch), layer(AIGraphData_V0.Layer)
    }
}

extension AIGraphData_V0.PatchOrLayer: StitchAIValueStringConvertable {
    var encodableString: String {
        self.asLLMStepNodeName
    }
    
    var asLLMStepNodeName: String {
        switch self {
        case .patch(let x):
            // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot || Patch"
            return x.aiDisplayTitle
        case .layer(let x):
            return x.aiDisplayTitle
        }
    }
    
    public init?(_ description: String) {
        do {
            self = try Self.fromLLMNodeName(description)
        } catch {
            fatalErrorIfDebug("PatchOrLayer error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Note: Swift `init?` is tricky for returning nil vs initializing self; we have to both initialize self *and* return, else we continue past if/else branches etc.;
    // let's prefer functions with clearer return values
    static func fromLLMNodeName(_ nodeName: String) throws -> Self {
        // E.G. from "squareRoot || Patch", grab just the camelCase "squareRoot"
        if let nodeKindName = nodeName.components(separatedBy: "||").first?.trimmingCharacters(in: .whitespaces) {
            
            // Tricky: can't use `Patch(rawValue:)` constructor since newer patches use a non-camelCase rawValue
            if let patch = AIGraphData_V0.Patch.allCases.first(where: {
                // e.g. Patch.squareRoot 1-> "Square Root" -> "squareRoot"
                let patchDisplay = $0.defaultDisplayTitle().toCamelCase()
                return patchDisplay == nodeKindName
            }) {
                return .patch(patch)
            }
            
            //Handle cases where we have numbers...
            if nodeKindName == "base64StringToImage" {
                return .patch(.base64StringToImage)
            }
            
            if nodeKindName == "imageToBase64String" {
                return .patch(.imageToBase64String)
            }
            
            if nodeKindName == "arcTan2" {
                return .patch(.arcTan2)
            }
            
            else if let layer = AIGraphData_V0.Layer.allCases.first(where: {
                $0.defaultDisplayTitle().toCamelCase() == nodeKindName
            }) {
                return .layer(layer)
            }
        }
        
        throw StitchAIParsingError.nodeNameParsing(nodeName)
    }
    
    var description: String {
        switch self {
        case .patch(let patch):
            return patch.defaultDisplayTitle()
        case .layer(let layer):
            return layer.defaultDisplayTitle()
        }
    }
}

extension AIGraphData_V0.AILayerInputPort: Codable {
    /// Decodes a value that could be string, int, double, or JSON
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if value cannot be converted to string
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as different types, converting each to string
        if let stringValue = try? container.decode(String.self),
           let valueFromString = AIGraphData_V0.LayerInputPort.allCases
            .first(where: { $0.asLLMStepPort == stringValue }) {
            self.init(value: valueFromString)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "StitchAIStringConvertable: unexpected type for \(AIGraphData_V0.AILayerInputPort.self)"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value.asLLMStepPort)
    }
}

extension AIGraphData_V0.CustomPatchInputValue {
    enum CodingKeys: String, CodingKey {
        case patch_input_coordinate
        case value
        case value_type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.patch_input_coordinate = try container
            .decode(AIGraphData_V0.NodeIndexedCoordinate.self,
                    forKey: .patch_input_coordinate)
        
        let nodeType = try container.decode(AIGraphData_V0.StitchAINodeType.self, forKey: .value_type)
        
        // Parse value given node type
        let portValueType = nodeType.value.portValueTypeForStitchAI
        
        self.value_type = nodeType
        self.value = try container.decode(portValueType, forKey: .value)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patch_input_coordinate, forKey: .patch_input_coordinate)
        
        // Encodes values in manner that produces friendly printable result
        try AIGraphData_V0.PortValue.encodeFromAI(container: &container,
                                                  valueData: self.value,
                                                  valueType: self.value_type,
                                                  valueKey: .value,
                                                  valueTypeKey: .value_type)
    }
}

extension AIGraphData_V0.LayerData: Codable {
    enum CodingKeys: String, CodingKey {
        case node_id
        case suggested_title
        case node_name
        case children
        case custom_layer_input_values
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(node_id, forKey: .node_id)
        try container.encode(node_name, forKey: .node_name)
        try container.encode(custom_layer_input_values, forKey: .custom_layer_input_values)
        
        try container.encodeIfPresent(suggested_title, forKey: .suggested_title)
        
        // Only encode children if group layer
        try container.encodeIfPresent(children, forKey: .children)
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        node_id = try container.decode(String.self, forKey: .node_id)
        suggested_title = try container.decodeIfPresent(String.self, forKey: .suggested_title)
        node_name = try container.decode(AIGraphData_V0.StitchAIPatchOrLayer.self, forKey: .node_name)
        
        if let children = try container.decodeIfPresent([Self].self, forKey: .children) {
            self.children = children
        } else {
            // Make sure we have an empty list if layer is a group
            if node_name.value == .layer(.group) || node_name.value == .layer(.realityView) {
                self.children = []
            }
        }
    }
}

extension AIGraphData_V0.CustomLayerInputValue {
    init(id: UUID,
         input: AIGraphData_V0.LayerInputPort,
         value: AIGraphData_V0.PortValue) throws {
        let data = value.anyCodable
        
        self = .init(layer_input_coordinate: .init(
            layer_id: .init(id),
            input_port_type: .init(value: input)),
                     value: data,
                     value_type: .init(value: value.nodeType))
    }
}

extension AIGraphData_V0.CustomLayerInputValue: Codable {
    enum CodingKeys: String, CodingKey {
        case layer_input_coordinate
        case value
        case value_type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.layer_input_coordinate = try container
            .decode(AIGraphData_V0.LayerInputCoordinate.self,
                    forKey: .layer_input_coordinate)
        
        let nodeType = try container.decode(AIGraphData_V0.StitchAINodeType.self, forKey: .value_type)
        
        // Parse value given node type
        let portValueType = nodeType.value.portValueTypeForStitchAI
        
        self.value_type = nodeType
        self.value = try container.decode(portValueType, forKey: .value)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layer_input_coordinate, forKey: .layer_input_coordinate)
        
        // Encodes values in manner that produces friendly printable result
        try AIGraphData_V0.PortValue.encodeFromAI(container: &container,
                                                  valueData: self.value,
                                                  valueType: self.value_type,
                                                  valueKey: .value,
                                                  valueTypeKey: .value_type)
    }
}

// TODO: move
extension AIGraphData_V0.PortValue {
    static func decodeFromAI(data: (any Codable & Sendable),
                             valueType: AIGraphData_V0.NodeType,
                             idMap: inout [String : UUID]) throws -> AIGraphData_V0.PortValue {
        do {
            let value = try valueType.coerceToPortValueForStitchAI(from: data,
                                                                   idMap: idMap)
            return value
        } catch {
            // Decode into specific type before casing--sometimes necessary
            guard let data = data as? Data else {
                fatalErrorIfDebug()
                throw SwiftUISyntaxError.portValueDataDecodingFailure
            }
            
            let decodedData = try JSONDecoder()
                .decode(valueType.portValueTypeForStitchAI, from: data)
            
            let value = try valueType.coerceToPortValueForStitchAI(from: decodedData,
                                                                   idMap: idMap)
            return value
        }
    }
    
    static func encodeFromAI<CodingKeys: CodingKey>(container: inout KeyedEncodingContainer<CodingKeys>,
                                                    portValue: AIGraphData_V0.PortValue,
                                                    valueKey: CodingKeys,
                                                    valueTypeKey: CodingKeys) throws {
        try container.encode(portValue.anyCodable, forKey: valueKey)
        try container.encode(portValue.nodeType, forKey: valueTypeKey)
    }
    
    static func encodeFromAI<CodingKeys: CodingKey>(container: inout KeyedEncodingContainer<CodingKeys>,
                                                    valueData: any Codable,
                                                    valueType: AIGraphData_V0.StitchAINodeType,
                                                    valueKey: CodingKeys,
                                                    valueTypeKey: CodingKeys) throws {
        try container.encode(valueType, forKey: valueTypeKey)
        
        // Encodes values with friendly format
        if let data = valueData as? Data {
            var fakeMap = [String : UUID]()
            let portValue = try AIGraphData_V0.PortValue.decodeFromAI(data: data,
                                                                      valueType: valueType.value,
                                                                      idMap: &fakeMap)
            
            try container.encode(portValue.anyCodable, forKey: valueKey)
        } else {
            try container.encode(valueData, forKey: valueKey)
        }
    }
}

extension Array where Element == AIGraphData_V0.LayerData {
    var allNestedCustomInputValues: [AIGraphData_V0.CustomLayerInputValue] {
        self.flatMap {
            $0.custom_layer_input_values +
            ($0.children?.allNestedCustomInputValues ?? [])
        }
    }
}

extension AIGraphData_V0.LayerData {
    func createSidebarLayerData(idMap: [String : UUID]) throws -> SidebarLayerData {
        guard let newId = idMap.get(self.node_id) else {
            throw AIPatchBuilderRequestError.nodeIdNotFound
        }
        
        let children = try self.children?.map {
            try $0.createSidebarLayerData(idMap: idMap)
        }
        
        return SidebarLayerData(id: newId,
                                children: children)
    }
}

extension AIGraphData_V0.NodeType: StitchAIValueStringConvertable {
    public init?(_ description: String) {
        guard let type = Self.init(llmString: description) else {
            return nil
        }
        
        self = type
    }
    
    var encodableString: String {
        self.description
    }
    
    public var description: String {
        self.asLLMStepNodeType
    }
}

extension CurrentAIGraphData.JavaScriptPortDefinition {
    init(_ portDefinition: JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI) throws {
        let migratedNodeType = try NodeTypeVersion
            .migrate(entity: portDefinition.strict_type,
                     version: CurrentAIGraphData.documentVersion)
        
        self.init(label: portDefinition.label,
                  strictType: migratedNodeType)
    }
}
