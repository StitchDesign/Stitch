//
//  NetworkRequestUITestView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// For testing

//@MainActor
//struct NetworkRequestReplView: View {
//
//    @Bindable private var store = StitchStore()
//
//    @State private var result: String = "no result yet..."
//
//    @State private var resultImage: UIImage?
//
//    var body: some View {
//
//        //        let dispatch: Dispatch = { state.dispatch($0) }
//
//        if let image = resultImage {
//            Image(uiImage: image).resizable().scaledToFit()
//        }
//
//        Text("Make Request").font(.headline).onTapGesture {
//            log("make request text tapped")
//            let delayPOSTUrl: URL = URL(string: "https://httpbin.org/delay/6")!
//            let postRequest: URLRequest = simplePOSTRequest(url: delayPOSTUrl)
//
//            //            let jsonBodyPOSTUrl: URL = URL(string: "https://reqbin.com/echo/post/json")!
//            //            let jsonBodyString = "{\"Id\": 78912, \"Customer\": \"Jason Sweet\", \"Quantity\": 1, \"Price\": 18.00}"
//            //
//            //            let jsonBodyPostRequest: URLRequest = jsonPOSTRequest(
//            //                url: jsonBodyPOSTUrl,
//            //                body: parseJSON(jsonBodyString)!,
//            //                headers: emptyJSON)
//
//            let f = futureRequest(urlRequest: postRequest)
//
//            //        let nodeType: UserVisibleType = .image
//            let nodeType: UserVisibleType = .json
//
//            f.onSuccess { (d: Data?, r: URLResponse?) in
//                // can still have 'failed' for our purposes, if we didn't get the response we wanted
//
//                let result = handleRequestResponse(
//                    data: d,
//                    response: r,
//                    error: nil)
//
//                log("success: result: \(result)")
//
//                if case let .success(x) = result,
//                   case let .image(x2) = x.0 {
//                    resultImage = x2
//                }
//
//            }.onFailure { (error: AnyError) in
//                let result = handleRequestResponse(
//                    data: nil,
//                    response: nil,
//                    error: error)
//
//                log("error: result: \(result)")
//
//                log("createErrorJSON(error: error.localizedDescription): \(createErrorJSON(error: error.localizedDescription))")
//            }
//        }.padding()
//    }
//}
//
//struct NetworkRequestReplView_Previews: PreviewProvider {
//    static var previews: some View {
//        NetworkRequestReplView()
//    }
//}
