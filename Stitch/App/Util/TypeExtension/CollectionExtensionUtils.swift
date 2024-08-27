//
//  CollectionExtensionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import NonEmpty
import OrderedCollections

typealias NEA = NonEmptyArray
typealias NES = NonEmptySet

// for safe indexing
extension Array {
    public subscript(safeIndex index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }

    /// Similar to `filter` but accepts nil return type.
    func compactFilter(_ callback: @escaping (Element) -> Bool?) -> Self {
        self.filter { callback($0) == true }
    }
}

// for using dictionary subscript at a function
extension Dictionary {
    public func get(_ key: Key) -> Value? {
        self[key]
    }

    var toValuesArray: [Values.Element] {
        Array(self.values)
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Collection {
    var tail: [Element] {
        Array(self.dropFirst())
    }
}

// Can simplify dictionary merging when using UUIDs as keys
extension Dictionary where Key == NodeId {
    func merge(with secondDict: Self) -> Self {
        var d = self
        secondDict.forEach { (key: NodeId, value: Value) in
            d.updateValue(value, forKey: key)
        }
        return d
    }
}

// Works for sorting GroupNodeId, which conforms to
extension Dictionary where Key: Identifiable {
    func merge(with secondDict: Self) -> Self {
        var d = self
        secondDict.forEach { (key: Key, value: Value) in
            d.updateValue(value, forKey: key)
        }
        return d
    }
}

// https://stackoverflow.com/questions/45340536/get-next-or-previous-item-to-an-object-in-a-swift-collection-or-array
extension BidirectionalCollection where Iterator.Element: Equatable {
    typealias Element = Self.Iterator.Element

    func after(_ item: Element, loop: Bool = false) -> Element? {
        if let itemIndex = self.firstIndex(of: item) {
            let lastItem: Bool = (index(after:itemIndex) == endIndex)
            if loop && lastItem {
                return self.first
            } else if lastItem {
                return nil
            } else {
                return self[index(after:itemIndex)]
            }
        }
        return nil
    }

    func before(_ item: Element, loop: Bool = false) -> Element? {
        if let itemIndex = self.firstIndex(of: item) {
            let firstItem: Bool = (itemIndex == startIndex)
            if loop && firstItem {
                return self.last
            } else if firstItem {
                return nil
            } else {
                return self[index(before:itemIndex)]
            }
        }
        return nil
    }
}

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}

extension Set {
    func pureInsert(_ item: Element) -> Self {
        var set = self
        set.insert(item)
        return set
    }
}

extension Collection where Element: Hashable {
    var toSet: Set<Element> {
        Set(self)
    }
}

extension Collection where Element: Hashable {
    var toOrderedSet: OrderedSet<Element> {
        OrderedSet.init(self)
    }
}
