//
//  File.swift
//  Plist
//
//  Created by my on 2023/1/4.
//

import Foundation

public protocol PlistArrayCacheCompatible {
    func isValueExistsForKey(_ key: Int) -> Bool
    
    func setValue(_ value: Any?, for key: Int)
    
    func value(for key: Int) -> Any?
}

public final class PlistArrayNoneCache: PlistArrayCacheCompatible {
    public func value(for index: Int) -> Any? { nil }
    
    public func setValue(_ value: Any?, for index: Int) {}
    
    public func isValueExistsForKey(_ index: Int) -> Bool { false }
}

extension PlistCache: PlistArrayCacheCompatible where Key == Int {}

public enum PlistArrayCacheStrategy {
    case none
    case `default`
    case custom(PlistArrayCacheCompatible)
    
    var cache: PlistArrayCacheCompatible {
        switch self {
        case .none: return PlistArrayNoneCache()
        case .default: return PlistCache<Int>(capacity: 20, queue: DispatchQueue(label: "com.ge.plist.cache.queue"))
        case let .custom(cache): return cache
        }
    }
}

public final class PlistArray: PlistContainer<[Any]> {
    let lock = DispatchSemaphore(value: 1)
    public let cache: PlistArrayCacheCompatible
    public init(cacheStrategy: PlistArrayCacheStrategy = .default, configuration: PlistContainerConfiguration) {
        self.cache = cacheStrategy.cache
        super.init(container: [], configuration: configuration)
    }
    
    public var count: Int { container.count }
    
    public func value<T>(at index: Int, with type: T.Type, defaultValue: T? = nil) -> T? {
        if let value = cache.value(for: index) as? T {
            return value
        }
        
        if configuration.shouldCacheOriginData {
            return readValue(at: index, with: type, from: container) ?? defaultValue
        }
        
        if let _container = readContainerSynchronize() {
            return readValue(at: index, with: type, from: _container) ?? defaultValue
        }
        
        return defaultValue
    }
    
    public func appendValue<T>(_ value: T) {
        lock.lock(); defer { lock.unlock() }
        do {
            var _container = container
            try setValue(value: value, at: count, with: &_container)
            try setContainer(_container)
            cache.setValue(value, for: _container.count - 1)
        } catch {
            delegate?.plist(errorOccurred: PlistError.encodeTypeError)
        }
    }
        
    public func setValue<T>(_ value: T?, at index: Int) {
        lock.lock(); defer { lock.unlock() }
        precondition(index < count)
        
        do {
            var _container = container
            if value == nil {
                _container.remove(at: index)
            } else {
                try setValue(value: value!, at: index, with: &_container)
            }
            
            try setContainer(_container)
            cache.setValue(value, for: index)
        } catch {
            delegate?.plist(errorOccurred: PlistError.encodeTypeError)
        }
    }
}

extension PlistArray {
    
    private func readValue<T>(at index: Int, with type: T.Type, from container: [Any]) -> T? {
        guard index < container.count else { return nil }
        let value = container[index]
        
        if let _value = value as? T {
            cache.setValue(_value, for: index)
            return _value
        }
        
        if let codableType = type as? Codable.Type, let _value = readCodableValue(with: value, type: codableType) {
            cache.setValue(_value, for: index)
            return _value as? T
        }
        
        return nil
    }
    
    private func readCodableValue<T: Codable>(with object: Any, type: T.Type) -> T? {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: .bitWidth)
            let decoder = PropertyListDecoder()
            let value = try decoder.decode(type, from: data)
            return value
        } catch {
            delegate?.plist(errorOccurred: .decode(error))
            return nil
        }
    }
    
    private func setValue<T>(value: T, at index: Int, with container: inout [Any]) throws {
        if let _value = value as? PlistIsBasicCodableType {
            safeInsertValue(_value, at: index, with: &container)
        } else if let array = value as? [Any], array.isPlistData {
            safeInsertValue(array, at: index, with: &container)
        } else if let dictionary = value as? [String: Any], dictionary.isPlistData {
            safeInsertValue(dictionary, at: index, with: &container)
        } else if let codableValue = value as? Codable {
            setCodableValue(codableValue, at: index, with: &container)
        } else {
            throw PlistError.encodeTypeError
        }
    }

    private func setCodableValue<T: Codable>(_ value: T, at index: Int, with container: inout [Any]) {
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(value)
            let object = try PropertyListSerialization.propertyList(from: data, format: nil)
            safeInsertValue(object, at: index, with: &container)
        } catch {
            delegate?.plist(errorOccurred: .encode(error))
        }
    }
    
    private func safeInsertValue(_ value: Any, at index: Int, with container: inout [Any]) {
        if index < container.count {
            container[index] = value
        } else {
            container.append(value)
        }
    }
}
