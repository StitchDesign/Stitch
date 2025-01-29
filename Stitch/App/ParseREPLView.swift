//
//  ParseREPLView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/29/25.
//

import SwiftUI
import SwiftyJSON

struct ParseREPLView: View {
    
    let string: String = "{\"x\": 0.5, \"y\": 0.5}"
    
    var parsedValue: PortValue? {
        if let data = string.data(using: .utf8) {
            let decoder = JSONDecoder()
            let value: PortValue? = try? decoder.decode(PortValue.self, from: data)
            return value
        }
        
        return nil
    }
    
    var body: some View {
        Text("\(parsedValue)")
            .padding()
    }
}

#Preview {
    ParseREPLView()
}
