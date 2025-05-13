//
//  StitchAITips.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/12/25.
//

import TipKit

struct StitchAILaunchTip: Tip {
    var title: Text {
        Text("Stitch AI")
    }
    
    var message: Text? {
        Text("Search patches, layers, or simply ask Stitch AI.")
    }
    
    var image: Image? {
        Image(systemName: "sparkles")
    }
}


struct StitchAITrainingTip: Tip {
    var title: Text {
        Text("Help Improve Stitch AI")
    }
    
    var message: Text? {
        Text("Click here to correct results from Stitch AI. Corrections can be submitted to Stitch for improving Stitch AI's accuracy.")
    }
}
