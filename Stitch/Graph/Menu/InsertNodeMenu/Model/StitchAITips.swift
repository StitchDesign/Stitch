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
