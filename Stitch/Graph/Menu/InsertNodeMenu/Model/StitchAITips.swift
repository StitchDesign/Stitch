//
//  StitchAITips.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/12/25.
//

import TipKit

struct StitchAILaunchTip: Tip {
    private static let tipBody = """
Search patches, layers, or simply ask Stitch AI. \
[Click here](https://github.com/StitchDesign/Stitch/blob/development/StitchAI%20-%20UserGuide.md) for more info.
"""
    
    var title: Text {
        Text("Stitch AI")
    }
    
    var message: Text? {
        Text(.init(Self.tipBody))
    }
    
    var image: Image? {
        Image(systemName: "sparkles")
    }
}

// TODO: since we're using a stateful static var + Rule, do we still need to call `.invalidate(reason:)` on a given instance of this tip?
// https://fatbobman.com/en/posts/mastering-tipkit-advance/
struct StitchAITrainingTip: Tip {

    var title: Text {
        Text("Help Improve Stitch AI")
    }
    
    var message: Text? {
        Text("Click here to correct results from Stitch AI. Corrections can be submitted to Stitch for improving Stitch AI's accuracy.")
    }
    
    // Note: this is a *stateful* `static var`
    // https://www.createwithswift.com/displaying-tips-based-on-parameters-and-events-with-tipkit/
    @Parameter
    static var hasCompletedOpenAIRequest: Bool = false
    
    // https://developer.apple.com/documentation/tipkit/tips/rule
    var rules: [Rule] {
        #Rule(Self.$hasCompletedOpenAIRequest) {
            $0 == true
        }
    }
}
