//
//  AIGraphDescriptionRequestBody_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/7/25.
//

enum AIGraphDescriptionRequestBody_V0 {
    struct AIGraphDescriptionRequestBody: Encodable {
        let model: String
        let n: Int = 1
        let temperature: Double = 0.0
        let messages: [OpenAIMessage]
        let stream = false
        
        init(secrets: Secrets,
             userPrompt: String) {
            let systemPrompt = AIGraphDescriptionSystemPrompt_V0.systemPrompt

            self.model = secrets.openAIModelGraphDescription
            self.messages = [
                .init(role: .system,
                      content: systemPrompt),
                .init(role: .user,
                      content: userPrompt)
            ]
        }
    }
}
