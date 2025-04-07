//
//  DateAndTimeFormatterNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/29/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension DateAndTimeFormat: PortValueEnum {
    static let defaultFormat = Self.medium

    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.dateAndTimeFormat
    }

    var toDateFormatterStyle: DateFormatter.Style? {
        switch self {
        case .none:
            return nil
        case .short:
            return .short
        case .medium:
            return .medium
        case .long:
            return .long
        case .full:
            return .full
        }
    }

    var display: String {
        switch self {
        case .none:
            return "None"
        case .short:
            return  "Short Date (YYYY-MM-DD)"
        case .medium:
            return  "Medium Date (Jan 1, 1970)"
        case .long:
            return  "Long Date (January 1, 1970)"
        case .full:
            return  "Full Date & Time (January 1, 1970 at 12:00 AM)"
        }
    }
}

extension String {
    static let empty = ""
}

// No node type or user-node types
// No inputs (ie inputs are disabled
@MainActor
func dateAndTimeFormatterNode(id: NodeId,
                              position: CGPoint = .zero,
                              zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            ("Time", [.number(.zero)]),
        ("Format", [.dateAndTimeFormat(.defaultFormat)]),
        // TODO: allow user to provide custom format option
        ("Custom Format", [.string(.init(.empty))])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.string(.init(.empty))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .dateAndTimeFormatter,
        inputs: inputs,
        outputs: outputs)
}

// dateAndTimeFormatter is the only node that needs graphFrameCount from state;
@MainActor
func dateAndTimeFormatterEval(inputs: PortValuesList,
                              outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in

        if let time = values.first?.getNumber,
           let format = values[1].getDateAndTimeFormat,
           // TODO: actually use customFormat
           let _ = values[2].getString {

            let date = Date(timeIntervalSince1970: time)
            let dateFormatter = DateFormatter()

            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            if let style = format.toDateFormatterStyle {
                dateFormatter.dateStyle = style
                dateFormatter.timeStyle = style
                return .string(.init(dateFormatter.string(from: date)))
            } else {
                return .string(.init(date.description))
            }

        } else {
            log("dateAndTimeFormatterEval: could not eval", .logToServer)
            return .string(.init(.empty))
        }
    }

    return resultsMaker(inputs)(op)
}

#if DEV_DEBUG
struct DateTimeFormat_REPL: View {

    var date: Date {
        //        Date(timeIntervalSinceReferenceDate: 118800)
        //        Date(timeIntervalSinceReferenceDate: 0)
        Date(timeIntervalSince1970: 118800)
    }

    var formatted: String {
        /*
         DateFormatter.Style overview: // https://developer.apple.com/documentation/foundation/dateformatter/1415411-datestyle

         short = numeric only
         https://developer.apple.com/documentation/foundation/dateformatter/style/short
         Specifies a short style, typically numeric only, such as “11/23/37” or “3:30 PM”.

         medium = abbreviated text
         https://developer.apple.com/documentation/foundation/dateformatter/style/medium
         Specifies a medium style, typically with abbreviated text, such as “Nov 23, 1937” or “3:30:32 PM”.

         long = full text
         https://developer.apple.com/documentation/foundation/dateformatter/style/long
         Specifies a long style, typically with full text, such as “November 23, 1937” or “3:30:32 PM PST”.

         full = full text + details
         https://developer.apple.com/documentation/foundation/dateformatter/style/full
         Specifies a full style with complete details, such as “Tuesday, April 12, 1952 AD” or “3:30:42 PM Pacific Standard Time”.
         */
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium // .full

        // https://developer.apple.com/documentation/foundation/dateformatter/1413467-timestyle

        // https://developer.apple.com/documentation/foundation/dateformatter/1413514-dateformat
        // custom format
        //        dateFormatter.dateFormat

        return dateFormatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("date: \(date)")
            Text("formatted: \(formatted)")
        }
    }
}

struct DateTimeFormat_Previews: PreviewProvider {
    static var previews: some View {
        DateTimeFormat_REPL()
    }
}
#endif
