//
//  ArrayUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/25.
//

import Foundation

extension Sequence {
    // A true `map` function (map, compactMap, flatMap) takes a function that can return a different type than the original collection's member
    // https://en.wikipedia.org/wiki/Functor_(functional_programming)
    func recursiveCompactMap<T>(fn: (Element) -> T?, // the actual fn
                                // How to access the children
                                children: (Element) -> [Element]?,
                                // How to put the children back into the parent
                                makeWithChildren: (T, [T]) -> T) -> [T] {
        self.compactMap { element in
            let mappedChildren = (children(element) ?? []).recursiveCompactMap(
                fn: fn,
                children: children,
                makeWithChildren: makeWithChildren
            )

            if let mapped = fn(element) {
                return makeWithChildren(mapped, mappedChildren)
            } else if let mappedChild = mappedChildren.first {
                // No direct mapping, but keep children
                // Assuming `fn` returns nil because element is just a container
                return makeWithChildren(mappedChild, Array(mappedChildren.dropFirst()))
            } else {
                return nil
            }
        }
    }
}
