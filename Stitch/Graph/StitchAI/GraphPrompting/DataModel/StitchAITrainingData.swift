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
                print("❌ StitchAITraining failure at example \(index+1): Could not convert message to Data")
                return nil
            }
            
            do {
                let actionsData = try jsonDecoder.decode(StitchAIActionsTrainingData.self, from: messageData)
                return actionsData
            } catch {
                print("❌ StitchAITrainingData validation error at example \(index+1): Step decoding failed")
                print("   Error: \(error)")
                print("   Message content: \(message)")
                return nil
            }
        }
        
        return actionsDataList
    }
}

// MARK: - o4-mini (reasoning) data ------------------------------------------
/// New format: no `"completion"` field – the assistant's `content` **is** the
/// array of `Step`s.
/// Old format (still accepted): a top-level `"completion"` object.
struct StitchAIReasoningTrainingData: Decodable {
    let messages:   [OpenAIMessage]
    let completion: StitchAIActionsTrainingData?     // optional now
}

extension StitchAIReasoningTrainingData: StitchAITrainingDataValidatable {
    static func getTrainingData(from datasetExamples: [Self]) -> [StitchAIActionsTrainingData] {
        let decoder = JSONDecoder()

        return datasetExamples.enumerated().compactMap { (index, example) in
            // 1️⃣ Preferred: explicit `"completion"`
            if let completion = example.completion {
                print("✅ Example \(index+1): Using explicit completion field")
                return completion
            }

            // 2️⃣ Fallback: pull from last assistant message
            guard let assistantContent = example.messages.last(where: { $0.role == .assistant })?.content else {
                print("❌ Example \(index+1): No assistant message found")
                print("   Available message roles: \(example.messages.map { $0.role.rawValue })")
                return nil
            }
            
            guard let data = assistantContent.data(using: .utf8) else {
                print("❌ Example \(index+1): Could not convert assistant content to Data")
                print("   Content: \(assistantContent)")
                return nil
            }
            
            do {
                let actions = try decoder.decode(StitchAIActionsTrainingData.self, from: data)
                print("✅ Example \(index+1): Successfully decoded actions from assistant message (\(actions.actions.count) actions)")
                return actions
            } catch {
                print("❌ Example \(index+1): Could not decode StitchAIActionsTrainingData from assistant message")
                print("   Error: \(error)")
                print("   Assistant content: \(assistantContent)")
                return nil
            }
        }
    }
}

// MARK: - Supports BOTH shapes
struct StitchAIActionsTrainingData: Decodable {
    let actions: [Step]

    init(from decoder: Decoder) throws {
        //Try the new, bare-array form first.
        if let single = try? decoder.singleValueContainer(),
           let steps  = try? single.decode([Step].self) {
            self.actions = steps
            return
        }

        //Fallback to legacy keyed form `{ "actions": [...] }`
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.actions = try keyed.decode([Step].self, forKey: .actions)
    }

    private enum CodingKeys: String, CodingKey {
        case actions
    }
}

enum StitchAITrainingError: Error {
    case fileNotFound
}

extension StitchAITrainingDataValidatable {
    static func validateTrainingData(from filename: String) throws {
        print("🔍 Starting validation for dataset: \(filename)")
        
        let trainingData = try Self.decodeTrainingData(from: filename)
        print("📊 Loaded \(trainingData.count) examples from \(filename)")
        
        let actionsDataList: [StitchAIActionsTrainingData] = Self.getTrainingData(from: trainingData)
        print("✨ Successfully extracted actions from \(actionsDataList.count)/\(trainingData.count) examples")
        
        var totalValidationErrors = 0
        var successfulExamples = 0
        var failedExamples = 0
        
        for (index, actionsData) in actionsDataList.enumerated() {
            print("\n🔎 Validating example \(index+1) with \(actionsData.actions.count) actions...")
            
            var validationErrors: [String] = []
            
            for (stepIndex, step) in actionsData.actions.enumerated() {
                let stepResult = StepTypeAction.fromStep(step)
                
                switch stepResult {
                case .success:
                    // Step is valid
                    continue
                case .failure(let error):
                    let errorMessage = "Step \(stepIndex+1): \(error) - Step details: \(step.description)"
                    validationErrors.append(errorMessage)
                }
            }
            
            if validationErrors.isEmpty {
                print("✅ Example \(index+1): All \(actionsData.actions.count) actions are valid")
                successfulExamples += 1
            } else {
                print("❌ Example \(index+1): \(validationErrors.count) validation errors found:")
                for (errorIndex, errorMessage) in validationErrors.enumerated() {
                    print("   \(errorIndex+1). \(errorMessage)")
                }
                totalValidationErrors += validationErrors.count
                failedExamples += 1
            }
        }
        
        let extractionFailures = trainingData.count - actionsDataList.count
        
        print("\n" + String(repeating: "=", count: 60))
        print("📈 FINAL VALIDATION SUMMARY for \(filename):")
        print(String(repeating: "=", count: 60))
        print("   📄 Total examples in file: \(trainingData.count)")
        print("   ❌ Failed action extraction: \(extractionFailures)")
        print("   ✅ Successfully extracted actions: \(actionsDataList.count)")
        print("   🔴 Failed validation: \(failedExamples)")
        print("   ✅ Passed validation: \(successfulExamples)")
        print("   💥 Total validation errors: \(totalValidationErrors)")
        print(String(repeating: "=", count: 60))
        
        if extractionFailures == 0 && successfulExamples == actionsDataList.count {
            print("🎉 PERFECT! All examples passed validation!")
        } else {
            if extractionFailures > 0 {
                print("⚠️  \(extractionFailures) examples failed during action extraction")
            }
            if failedExamples > 0 {
                print("⚠️  \(failedExamples) examples failed validation checks")
            }
            print("📝 See detailed errors above for debugging information")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    static func decodeTrainingData(from filename: String) throws -> [Self] {
        print("📁 Reading file: \(filename).jsonl")
        
        let jsonArray = try Self.convertJSONLToJSON(from: filename)
        print("📄 Parsed \(jsonArray.count) JSON objects from JSONL file")
        
        let decoder = JSONDecoder()

        let data = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted])
        
        do {
            let messages = try decoder.decode([Self].self, from: data)
            print("✅ Successfully decoded \(messages.count) training examples")
            return messages
        } catch {
            print("❌ Failed to decode training data: \(error)")
            throw error
        }
    }
    
    static func convertJSONLToJSON(from filename: String) throws -> [Any] {
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "jsonl") else {
            print("❌ File not found: \(filename).jsonl")
            throw StitchAITrainingError.fileNotFound
        }
        
        // Read the entire content of the file as a single String
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        print("📖 Read file contents (\(fileContents.count) characters)")
        
        // Split the file contents by newlines
        let lines = fileContents.components(separatedBy: .newlines)
        print("📝 Split into \(lines.count) lines")
        
        // Parse each line into a JSON object
        var jsonObjects: [Any] = []
        var emptyLines = 0
        var parseErrors = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !trimmedLine.isEmpty else {
                emptyLines += 1
                continue
            }
            
            // Convert the line to Data
            if let data = trimmedLine.data(using: .utf8) {
                do {
                    // Deserialize the JSON object
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    jsonObjects.append(jsonObject)
                } catch {
                    parseErrors += 1
                    print("❌ Line \(lineIndex+1): JSON parsing error - \(error)")
                    print("   Content: \(trimmedLine.prefix(200))...")
                }
            }
        }
        
        print("📊 JSONL Parsing summary:")
        print("   Total lines: \(lines.count)")
        print("   Empty lines: \(emptyLines)")
        print("   Parse errors: \(parseErrors)")
        print("   Valid JSON objects: \(jsonObjects.count)")
        
        return jsonObjects
    }
}
