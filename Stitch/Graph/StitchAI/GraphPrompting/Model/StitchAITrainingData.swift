//
//  StitchAITrainingData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/18/25.
//

import SwiftUI

protocol StitchAITrainingDataValidatable: Decodable {
    static func getTrainingData(from datasetExamples: [Self]) -> [StitchAIActionsTrainingData]
    static func getTrainingDataWithRowTracking(from datasetExamples: [(example: Self, rowNumber: Int)]) -> [(actions: StitchAIActionsTrainingData, rowNumber: Int)]
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
    
    static func getTrainingDataWithRowTracking(from datasetExamples: [(example: Self, rowNumber: Int)]) -> [(actions: StitchAIActionsTrainingData, rowNumber: Int)] {
        let jsonDecoder = JSONDecoder()
        
        return datasetExamples.compactMap { (example, rowNumber) in
            guard let assistantMessage = example.messages.first(where: { $0.role == .assistant })?.content else {
                print("❌ Row \(rowNumber): No assistant message found")
                return nil
            }
            
            guard let messageData = assistantMessage.data(using: .utf8) else {
                print("❌ Row \(rowNumber): Could not convert message to Data")
                return nil
            }
            
            do {
                let actionsData = try jsonDecoder.decode(StitchAIActionsTrainingData.self, from: messageData)
                return (actions: actionsData, rowNumber: rowNumber)
            } catch {
                print("❌ Row \(rowNumber): Step decoding failed")
                print("   Error: \(error)")
                print("   Message content: \(assistantMessage.prefix(200))...")
                return nil
            }
        }
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
    
    static func getTrainingDataWithRowTracking(from datasetExamples: [(example: Self, rowNumber: Int)]) -> [(actions: StitchAIActionsTrainingData, rowNumber: Int)] {
        let decoder = JSONDecoder()

        return datasetExamples.compactMap { (example, rowNumber) in
            // 1️⃣ Preferred: explicit `"completion"`
            if let completion = example.completion {
                print("✅ Row \(rowNumber): Using explicit completion field")
                return (actions: completion, rowNumber: rowNumber)
            }

            // 2️⃣ Fallback: pull from last assistant message
            guard let assistantContent = example.messages.last(where: { $0.role == .assistant })?.content else {
                print("❌ Row \(rowNumber): No assistant message found")
                print("   Available message roles: \(example.messages.map { $0.role.rawValue })")
                return nil
            }
            
            guard let data = assistantContent.data(using: .utf8) else {
                print("❌ Row \(rowNumber): Could not convert assistant content to Data")
                print("   Content: \(assistantContent.prefix(200))...")
                return nil
            }
            
            do {
                let actions = try decoder.decode(StitchAIActionsTrainingData.self, from: data)
                print("✅ Row \(rowNumber): Successfully decoded actions from assistant message (\(actions.actions.count) actions)")
                return (actions: actions, rowNumber: rowNumber)
            } catch {
                print("❌ Row \(rowNumber): Could not decode StitchAIActionsTrainingData from assistant message")
                print("   Error: \(error)")
                print("   Assistant content: \(assistantContent.prefix(200))...")
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
        
        let trainingDataWithRows = try Self.decodeTrainingDataWithRowTracking(from: filename)
        print("📊 Loaded \(trainingDataWithRows.count) examples from \(filename)")
        
        let actionsDataWithRows: [(actions: StitchAIActionsTrainingData, rowNumber: Int)] = Self.getTrainingDataWithRowTracking(from: trainingDataWithRows)
        print("✨ Successfully extracted actions from \(actionsDataWithRows.count)/\(trainingDataWithRows.count) examples")
        
        var totalValidationErrors = 0
        var successfulExamples = 0
        var failedExamples = 0
        var failedRows: [Int] = []
        
        for (actionsData, rowNumber) in actionsDataWithRows {
            print("\n🔎 Validating Row \(rowNumber) with \(actionsData.actions.count) actions...")
            
            var validationErrors: [String] = []
            
            for (stepIndex, step) in actionsData.actions.enumerated() {
                let stepResult = StepTypeAction.fromStep(step)
                
                switch stepResult {
                case .success:
                    // Step is valid
                    continue
                case .failure(let error):
                    let errorMessage = "Step \(stepIndex+1) [type: \(step.stepType.rawValue)]: \(error.description)"
                    validationErrors.append(errorMessage)
                }
            }
            
            if validationErrors.isEmpty {
                print("✅ Row \(rowNumber): All \(actionsData.actions.count) actions are valid")
                successfulExamples += 1
            } else {
                print("❌ Row \(rowNumber): \(validationErrors.count) validation errors found:")
                for (errorIndex, errorMessage) in validationErrors.enumerated() {
                    print("   \(errorIndex+1). \(errorMessage)")
                }
                totalValidationErrors += validationErrors.count
                failedExamples += 1
                failedRows.append(rowNumber)
            }
        }
        
        let extractionFailures = trainingDataWithRows.count - actionsDataWithRows.count
        
        print("\n" + String(repeating: "=", count: 60))
        print("📈 FINAL VALIDATION SUMMARY for \(filename):")
        print(String(repeating: "=", count: 60))
        print("   📄 Total examples in file: \(trainingDataWithRows.count)")
        print("   ❌ Failed action extraction: \(extractionFailures)")
        print("   ✅ Successfully extracted actions: \(actionsDataWithRows.count)")
        print("   🔴 Failed validation: \(failedExamples)")
        print("   ✅ Passed validation: \(successfulExamples)")
        print("   💥 Total validation errors: \(totalValidationErrors)")
        
        if !failedRows.isEmpty {
            print("   🚨 Failed rows: \(failedRows.map(String.init).joined(separator: ", "))")
        }
        
        let extractedRowNumbers = Set(actionsDataWithRows.map { $0.rowNumber })
        let allRowNumbers = Set(trainingDataWithRows.map { $0.rowNumber })
        let failedExtractionRows = Array(allRowNumbers.subtracting(extractedRowNumbers)).sorted()
        if !failedExtractionRows.isEmpty {
            print("   🚨 Failed extraction rows: \(failedExtractionRows.map(String.init).joined(separator: ", "))")
        }
        
        print(String(repeating: "=", count: 60))
        
        if extractionFailures == 0 && successfulExamples == actionsDataWithRows.count {
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
    
    static func decodeTrainingDataWithRowTracking(from filename: String) throws -> [(example: Self, rowNumber: Int)] {
        print("📁 Reading file: \(filename).jsonl")
        
        let jsonArrayWithRows = try Self.convertJSONLToJSONWithRowTracking(from: filename)
        print("📄 Parsed \(jsonArrayWithRows.count) JSON objects from JSONL file")
        
        let decoder = JSONDecoder()
        
        return jsonArrayWithRows.compactMap { (jsonObject, rowNumber) in
            do {
                let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
                let example = try decoder.decode(Self.self, from: data)
                return (example: example, rowNumber: rowNumber)
            } catch {
                print("❌ Failed to decode training data at row \(rowNumber): \(error)")
                return nil
            }
        }
    }
    
    static func convertJSONLToJSON(from filename: String) throws -> [Any] {
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "jsonl") else {
            print("❌ File not found: \(filename).jsonl")
            throw StitchAITrainingError.fileNotFound
        }
        
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        print("📖 Read file contents (\(fileContents.count) characters)")
        
        let lines = fileContents.components(separatedBy: .newlines)
        print("📝 Split into \(lines.count) lines")
        
        var jsonObjects: [Any] = []
        var emptyLines = 0
        var parseErrors = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !trimmedLine.isEmpty else {
                emptyLines += 1
                continue
            }
            
            if let data = trimmedLine.data(using: .utf8) {
                do {
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
    
    static func convertJSONLToJSONWithRowTracking(from filename: String) throws -> [(jsonObject: Any, rowNumber: Int)] {
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "jsonl") else {
            print("❌ File not found: \(filename).jsonl")
            throw StitchAITrainingError.fileNotFound
        }
        
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        print("📖 Read file contents (\(fileContents.count) characters)")
        
        let lines = fileContents.components(separatedBy: .newlines)
        print("📝 Split into \(lines.count) lines")
        
        var jsonObjectsWithRows: [(jsonObject: Any, rowNumber: Int)] = []
        var emptyLines = 0
        var parseErrors = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let rowNumber = lineIndex + 1
            
            guard !trimmedLine.isEmpty else {
                emptyLines += 1
                continue
            }
            
            if let data = trimmedLine.data(using: .utf8) {
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    jsonObjectsWithRows.append((jsonObject: jsonObject, rowNumber: rowNumber))
                } catch {
                    parseErrors += 1
                    print("❌ Row \(rowNumber): JSON parsing error - \(error)")
                    print("   Content: \(trimmedLine.prefix(200))...")
                }
            }
        }
        
        print("📊 JSONL Parsing summary:")
        print("   Total lines: \(lines.count)")
        print("   Empty lines: \(emptyLines)")
        print("   Parse errors: \(parseErrors)")
        print("   Valid JSON objects: \(jsonObjectsWithRows.count)")
        
        return jsonObjectsWithRows
    }
}
