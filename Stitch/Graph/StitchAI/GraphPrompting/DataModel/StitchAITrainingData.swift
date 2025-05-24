//
//  StitchAITrainingData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI

protocol StitchAITrainingDataValidatable: Decodable {
    static func getTrainingData(from datasetExamples: [Self]) -> [StitchAIActionsTrainingData]
}

struct StitchAITrainingData {
    let messages: [OpenAIMessage]
}

extension StitchAITrainingData: StitchAITrainingDataValidatable {
    static func getTrainingData(from datasetExamples: [Self]) -> [StitchAIActionsTrainingData] {
        let jsonDecoder = JSONDecoder()
        
        let assistantMessages = datasetExamples.compactMap {
            $0.messages.first { $0.role == .assistant }?.content
        }
        
        let actionsDataList: [StitchAIActionsTrainingData] = assistantMessages
            .enumerated()
            .compactMap { (index, message) in
            guard let messageData = message.data(using: .utf8) else {
                print("StitchAITraining failure: no data created")
                return nil
            }
            
            do {
                let actionsData = try jsonDecoder.decode(StitchAIActionsTrainingData.self, from: messageData)
                return actionsData
            } catch {
                print("StitchAITrainingData validation error with example \(index+1): Step decoding failed with error: \(error)")
                return nil
            }
        }
        
        return actionsDataList
    }
}

// used by o4-mini
struct StitchAIReasoningTrainingData: Decodable {
    let messages: [OpenAIMessage]
    
    // used by reasoning models
    let completion: StitchAIActionsTrainingData
}

extension StitchAIReasoningTrainingData: StitchAITrainingDataValidatable {
    static func getTrainingData(from datasetExamples: [Self]) -> [StitchAIActionsTrainingData] {
        datasetExamples.map(\.completion)
    }
}

struct StitchAIActionsTrainingData: Decodable {
    let actions: [Step]
}

enum StitchAITrainingError: Error {
    case fileNotFound
}

extension StitchAITrainingDataValidatable {
    static func validateTrainingData(from filename: String) throws {
        let trainingData = try Self.decodeTrainingData(from: filename)
        
        let actionsDataList: [StitchAIActionsTrainingData] = Self.getTrainingData(from: trainingData)
        
        for (index, actionsData) in actionsDataList.enumerated() {
            var validationErrors: [String] = []
            for step in actionsData.actions {
                do {
                    let _ = try StepTypeAction.fromStep(step)
                } catch {
                    validationErrors.append("Error: \(error)\nAction: \(step)")
                }
            }
            
            guard validationErrors.isEmpty else {
                print("StitchAITrainingData validation error with example \(index+1): Step action validation failed with the following errors:\n")
                for errorMessage in validationErrors {
                    print(errorMessage)
                }
                continue
            }
            
            print("StitchAITrainingData validation successful at \(index + 1)")
        }
    }
    
    static func decodeTrainingData(from filename: String) throws -> [Self] {
        let jsonArray = try Self.convertJSONLToJSON(from: filename)
        
        let decoder = JSONDecoder()

        let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted])
        
        let messages = try decoder.decode([Self].self,
                                          from: data)
        
        return messages
    }
    
    static func convertJSONLToJSON(from filename: String) throws -> [Any] {
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "jsonl") else {
            throw StitchAITrainingError.fileNotFound
        }
        
        // Read the entire content of the file as a single String
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        
        // Split the file contents by newlines
        let lines = fileContents.components(separatedBy: .newlines)
        
        // Parse each line into a JSON object
        var jsonObjects: [Any] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !trimmedLine.isEmpty else { continue }
            
            // Convert the line to Data
            if let data = trimmedLine.data(using: .utf8) {
                // Deserialize the JSON object
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                jsonObjects.append(jsonObject)
            }
        }
        
        return jsonObjects
    }
}

