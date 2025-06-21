//
//  SimpleParsing.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/20/25.
//

import SwiftSyntax
import SwiftParser
import CoreGraphics

enum InputValue {
  case cgFloat(CGFloat)
  case string(String)
  case cgSize(CGSize)
}

enum ViewAction {
  case createContainer(id: String, type: String)
  case createText(id: String, initialText: String)
  case setText(id: String, text: String)
  case createImage(id: String, initialName: String)
  case setImageName(id: String, name: String)
  case createRectangle(id: String)
  case setInput(id: String, input: String, value: InputValue)
}

class ViewActionVisitor: SyntaxVisitor {
  private var nextID = 0
  private var viewStack: [String] = []
  var actions: [ViewAction] = []

  private func makeID(prefix: String) -> String {
    defer { nextID += 1 }
    return "\(prefix)\(nextID)"
  }

  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    // ——— View constructors ———
    if let ident = node.calledExpression.as(IdentifierExprSyntax.self) {
      switch ident.identifier.text {
      case "HStack", "VStack", "ZStack":
        let id = makeID(prefix: ident.identifier.text.lowercased())
        actions.append(.createContainer(id: id, type: ident.identifier.text))
        viewStack.append(id)
        return .visitChildren

      case "Text":
        let id = makeID(prefix: "text")
        actions.append(.createText(id: id, initialText: ""))
        if
          let lit = node.argumentList.first?.expression
                        .as(StringLiteralExprSyntax.self),
          case let .stringSegment(seg)? = lit.segments.first
        {
          actions.append(.setText(id: id, text: seg.content.text))
        }
        viewStack.append(id)
        return .visitChildren

      case "Image":
        let id = makeID(prefix: "image")
        actions.append(.createImage(id: id, initialName: ""))
        if
          let arg = node.argumentList.first,
          arg.label?.text == "systemName",
          let lit = arg.expression.as(StringLiteralExprSyntax.self),
          case let .stringSegment(seg)? = lit.segments.first
        {
          actions.append(.setImageName(id: id, name: seg.content.text))
        }
        viewStack.append(id)
        return .visitChildren

      case "Rectangle":
        let id = makeID(prefix: "rectangle")
        actions.append(.createRectangle(id: id))
        viewStack.append(id)
        return .visitChildren

      default:
        break
      }
    }

    // ——— Modifiers ———
    if
      let member = node.calledExpression.as(MemberAccessExprSyntax.self),
      let current = viewStack.last
    {
      let name = member.name.text

      switch name {
      case "padding":
        if
          let intLit = node.argumentList.first?.expression
                          .as(IntegerLiteralExprSyntax.self),
          let value = Double(intLit.digits.text)
        {
          actions.append(.setInput(
            id: current,
            input: name,
            value: .cgFloat(CGFloat(value))
          ))
        }

      case "frame":
        if let tuple = node.argumentList.first?.expression
                           .as(TupleExprSyntax.self)
        {
          var w: CGFloat?
          var h: CGFloat?
          for elt in tuple.elementList {
            if let label = elt.label?.text {
                var numValue: Double?
                if let intLit = elt.expression.as(IntegerLiteralExprSyntax.self),
                   let intNum = Double(intLit.digits.text) {
                    numValue = intNum
                } else if let floatLit = elt.expression.as(FloatLiteralExprSyntax.self),
                          let floatNum = Double(floatLit.floatingDigits.text) {
                    numValue = floatNum
                }
                if let num = numValue {
                    switch label {
                    case "width":  w = CGFloat(num)
                    case "height": h = CGFloat(num)
                    default: break
                    }
                }
            }
          }
          if let width = w, let height = h {
            actions.append(.setInput(
              id: current,
              input: name,
              value: .cgSize(CGSize(width: width, height: height))
            ))
          }
        }

      case "border", "fill", "foregroundColor":
        // treat color args, e.g. ".red" or ".blue" as String
        let raw = node.argumentList.first?.expression
                      .description
                      .trimmingCharacters(in: .whitespacesAndNewlines)
               ?? ""
        actions.append(.setInput(
          id: current,
          input: name,
          value: .string(raw)
        ))

      default:
        break
      }

      return .visitChildren
    }

    return .visitChildren
  }

  override func visitPost(_ node: FunctionCallExprSyntax) {
    if
      let ident = node.calledExpression.as(IdentifierExprSyntax.self),
      ["HStack","VStack", "ZStack","Text","Image","Rectangle"]
        .contains(ident.identifier.text)
    {
      viewStack.removeLast()
    }
  }
}

func myTest() {
    let src = #"""
    HStack {
      Image(systemName: "document")
      VStack {
        Text("salut")
            .padding(16)
            .border(.red)
        Rectangle()
            .fill(.blue)
            .frame(width: 200, height: 100)
      }
    .padding(8)
    }
    """#

    let tree = Parser.parse(source: src)
    let v    = ViewActionVisitor(viewMode: .all)
    v.walk(tree)
    print(v.actions)
}
