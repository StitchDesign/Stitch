//
//  StitchAITrainingData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI

struct StitchAITrainingData: Decodable {
    let messages: [OpenAIMessage]
}

struct StitchAIActionsTrainingData: Decodable {
    let actions: [Step]
}

extension StitchAITrainingData {
    static func validateTrainingData(from filename: String) {
        let jsonDecoder = JSONDecoder()
        let trainingData = StitchAITrainingData
            .decodeTrainingData(from: "stitch-training")!
        let assistantMessages = trainingData.compactMap {
            $0.messages.first { $0.role == .assistant }?.content
        }
        
        for (index, message) in assistantMessages.enumerated() {
            guard let messageData = message.data(using: .utf8) else {
                log("StitchAITraining failure: no data created")
                continue
            }

            let actionsData: StitchAIActionsTrainingData
            
            do {
                actionsData = try jsonDecoder.decode(StitchAIActionsTrainingData.self, from: messageData)
            } catch {
                log("StitchAITrainingData validation error with example \(index+1): Step decoding failed with error: \(error)")
                continue
            }
            
            var validationErrors: [String] = []
            for step in actionsData.actions {
                do {
                    let _ = try StepTypeAction.fromStep(step)
                } catch {
                    validationErrors.append("Error: \(error)\nAction: \(step)")
                }
            }
            
            guard validationErrors.isEmpty else {
                log("StitchAITrainingData validation error with example \(index): Step action validation failed with the following errors:\n")
                for errorMessage in validationErrors {
                    log(errorMessage)
                }
                continue
            }
            
            log("StitchAITrainingData validation successful at \(index + 1)")
        }
    }
    
    static func decodeTrainingData(from filename: String) -> [Self]? {
        guard let jsonArray = Self.convertJSONLToJSON(from: filename) else {
            return nil
        }
        
        let decoder = JSONDecoder()

        do {
            let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted])

            let messages = try decoder.decode([Self].self,
                                              from: data)
            
            return messages
        } catch {
            print("Failed to convert array to JSON: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func convertJSONLToJSON(from filename: String) -> [Any]? {
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "jsonl") else {
            return nil
        }
        
        do {
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
        } catch {
            print("Failed to convert JSONL file: \(error.localizedDescription)")
            return nil
        }
    }
}

