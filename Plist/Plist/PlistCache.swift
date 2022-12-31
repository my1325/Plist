//
//  PlistCache.swift
//  Plist
//
//  Created by my on 2022/12/31.
//

import Foundation

public protocol PlistDictionaryCacheCompatible {
    func isValueExistsForKey(_ key: String) -> Bool
    
    func setValue(_ value: Any?, for key: String)
    
    func value(for key: String) -> Any?
}

public struct PlistDictionaryCacheEmpty: PlistDictionaryCacheCompatible {
    public func isValueExistsForKey(_ key: String) -> Bool {
        false
    }
    
    public func setValue(_ value: Any?, for key: String) {}
    
    public func value(for key: String) -> Any? {
        nil
    }
}

public enum PlistDictionaryStrategy {
    case none
    case `default`
    case custom(PlistDictionaryCacheCompatible)
    
    var cache: PlistDictionaryCacheCompatible {
        switch self {
        case .none: return PlistDictionaryCacheEmpty()
        case .default: return PlistCache(capacity: 20, queue: DispatchQueue(label: "com.ge.plist.cache.queue"))
        case let .custom(cache): return cache
        }
    }
}

public final class PlistLinkedListNode {
    public let key: String
    public var value: Any
    public fileprivate(set) var pre: PlistLinkedListNode?
    public fileprivate(set) var next: PlistLinkedListNode?
    init(key: String, value: Any, pre: PlistLinkedListNode? = nil, next: PlistLinkedListNode? = nil) {
        self.key = key
        self.value = value
        self.pre = pre
        self.next = next
    }
    
    fileprivate func removeFromList() {
        pre?.next = next
        next?.pre = pre
    }
}

public final class PlistLinkedList {
    
    public private(set) var count: Int = 0
    
    public private(set) var head: PlistLinkedListNode?
    
    public private(set) var tail: PlistLinkedListNode?
    
    public var isEmpty: Bool { count == 0 }
    
    public func add(_ value: Any, for key: String) -> PlistLinkedListNode {
        let newNode = PlistLinkedListNode(key: key, value: value)
        if head == nil {
            head = newNode
            tail = head
        } else {
            tail?.next = newNode
            newNode.pre = tail
            tail = newNode
        }
        count += 1
        return newNode
    }
    
    /// PlistLinkedListNode is not conform Equatable, so this method will not ensure the node is in list, it is not safe
    public func removeNode(_ node: PlistLinkedListNode) {
        guard isKeyInList(node.key) else { return }
        if node.pre == nil {
            head = node.next
        }
        
        if node.next == nil {
            tail = node.pre
        }
        
        node.removeFromList()
        count -= 1
    }
    
    @discardableResult
    public func removeValue<V: Equatable>(_ value: V) -> Bool {
        var _head = head
        while let node = _head {
            if let _value = node.value as? V, _value == value {
                removeNode(node)
                return true
            } else {
                _head = node.next
            }
        }
        return false
    }
    
    public func removeLastNode(_ k: Int = 1) -> [PlistLinkedListNode] {
        guard count > k, k > 0 else { return [] }
        var retValue: [PlistLinkedListNode] = []
        var _count = k
        while _count > 0, let node = tail {
            removeNode(node)
            _count -= 1
            retValue.append(node)
        }
        return retValue.reversed()
    }
    
    /// PlistLinkedListNode is not conform Equatable, so this method will not ensure the node is in list, it is not safe
    public func insertToHead(_ node: PlistLinkedListNode) {
        if let key = head?.key, key == node.key { return }
        removeNode(node)
        node.next = head
        head?.pre = node
        head = node
        if tail == nil {
            tail = node
        }
        count += 1
    }
    
    public func isKeyInList(_ key: String) -> Bool {
        var _head = head
        while _head != nil {
            if _head!.key == key {
                return true
            } else {
                _head = _head?.next
            }
        }
        return false
    }
}

public final class PlistCache: PlistDictionaryCacheCompatible {
    private let list: PlistLinkedList = PlistLinkedList()
    private var map: [String: PlistLinkedListNode] = [:]
    public let capacity: Int
    private let queue: DispatchQueue
    public init(capacity: Int, queue: DispatchQueue) {
        self.capacity = capacity
        self.queue = queue
    }
    
    public var isEmpty: Bool { list.isEmpty }
    
    public var count: Int { list.count }
    
    public func isValueExistsForKey(_ key: String) -> Bool {
        list.isKeyInList(key) && map.keys.contains(key)
    }
    
    /// this method will execute in the given queue
    public func setValue(_ value: Any?, for key: String) {
        if let _value = value {
            _addValue(_value, for: key)
        } else {
            _removeValue(for: key)
        }
    }
    
    public func removeValue(for key: String) {
        _removeValue(for: key)
    }
    
    public func value(for key: String) -> Any? {
        if let node = map[key] {
            list.insertToHead(node)
            return node.value
        }
        return nil
    }
    
    private func _addValue(_ value: Any, for key: String) {
        queue.async { [weak self] in
            if self?.isValueExistsForKey(key) == true, let node = self?.map[key] {
                node.value = value
                self?.list.insertToHead(node)
            } else if let node = self?.list.add(value, for: key) {
                self?.list.insertToHead(node)
                self?.map[key] = node
            }
            self?.ensureCapacity()
        }
    }
    
    private func _removeValue(for key: String) {
        queue.async { [weak self] in
            if let node = self?.map[key] {
                self?.list.removeNode(node)
            }
            self?.map.removeValue(forKey: key)
        }
    }
    
    private func ensureCapacity() {
        let sub = count - capacity
        for node in list.removeLastNode(sub) {
            map.removeValue(forKey: node.key)
        }
    }
}
