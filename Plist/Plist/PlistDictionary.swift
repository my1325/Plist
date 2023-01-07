//
//  PlistDictionary.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation
import FilePath

open class PlistDictionaryCoder: PlistContainerEncoder, PlistContainerDecoder {
    public func encodeContainer<T>(_ value: T) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: .bitWidth)
    }
    
    public func decodeContainer<T>(_ type: T.Type, from data: Data) throws -> T {
        if let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? T {
            return value
        } else {
            throw PlistError.decodeTypeError
        }
    }
}

public let plist_run_queue = "com.ge.plist.run.queue"
public extension PlistContainerConfiguration {
    static func plistWithPath(_ path: FilePath, queue: DispatchQueue = DispatchQueue(label: plist_run_queue)) -> PlistContainerConfiguration {
        let decoder = PlistDictionaryCoder()
        let encoder = PlistDictionaryCoder()
        return PlistContainerConfiguration(path: path, decoder: decoder, encoder: encoder, queue: queue, shouldCacheOriginData: true, readContainerSynchronize: true)
    }
}

public protocol PlistDictionaryCacheCompatible {
    func isValueExistsForKey(_ key: String) -> Bool
    
    func setValue(_ value: Any?, for key: String)
    
    func value(for key: String) -> Any?
}

public struct PlistDictionaryNoneCache: PlistDictionaryCacheCompatible {
    public func isValueExistsForKey(_ key: String) -> Bool { false }
    
    public func setValue(_ value: Any?, for key: String) {}
    
    public func value(for key: String) -> Any? { nil }
}

extension PlistCache: PlistDictionaryCacheCompatible where Key == String {}

public enum PlistDictionaryStrategy {
    case none
    case `default`
    case custom(PlistDictionaryCacheCompatible)
    
    var cache: PlistDictionaryCacheCompatible {
        switch self {
        case .none: return PlistDictionaryNoneCache()
        case .default: return PlistCache<String>(capacity: 20, queue: DispatchQueue(label: "com.ge.plist.cache.queue"))
        case let .custom(cache): return cache
        }
    }
}

public final class PlistDictionary: PlistContainer<[String: Any]> {
    let lock = DispatchSemaphore(value: 1)
    public let cache: PlistDictionaryCacheCompatible
    public init(cacheStrategy: PlistDictionaryStrategy = .default, configuration: PlistContainerConfiguration) {
        self.cache = cacheStrategy.cache
        super.init(container: [:], configuration: configuration)
    }
    
    public subscript<T: Codable>(keyPath: String) -> T? {
        get { value(for: keyPath, with: T.self) }
        set { setValue(newValue, for: keyPath) }
    }
    
    public func value<T>(for keyPath: String, with type: T.Type, defaultValue: T? = nil) -> T? {
        if cache.isValueExistsForKey(keyPath), let retValue = cache.value(for: keyPath) as? T {
            return retValue
        }
        
        if configuration.shouldCacheOriginData {
            return readValue(for: keyPath, with: type, from: container) ?? defaultValue
        }
        
        if let _container = readContainerSynchronize() {
            return readValue(for: keyPath, with: type, from: _container) ?? defaultValue
        }
        
        return defaultValue
    }
        
    public func setValue<T>(_ value: T?, for keyPath: String) {
        lock.lock(); defer { lock.unlock() }
        var _container = container
        let keyQueue = keyPath.split(separator: ".").filter { !$0.isEmpty }.map { String($0) }
        do {
            try setValue(value, for: keyQueue, with: &_container)
            try setContainer(_container)
            cache.setValue(value, for: keyPath)
        } catch {
            delegate?.plist(errorOccurred: .encodeTypeError)
        }
    }
}

extension PlistDictionary {
    private func rootForKeyPath(_ keyPath: String, with container: [String: Any]) -> (root: [String: Any]?, key: String) {
        var keyQueue = keyPath.split(separator: ".").filter { !$0.isEmpty }.map { String($0) }
        var root = container
        while keyQueue.count > 1 {
            if let value = root[keyQueue.removeFirst()], let _container = value as? [String: Any] {
                root = _container
            } else {
                delegate?.plist(errorOccurred: PlistError.decodeTypeError)
                return (nil, keyQueue.removeFirst())
            }
        }
        return (root, keyQueue.removeFirst())
    }
    
    private func readValue<T>(for keyPath: String, with type: T.Type, from container: [String: Any]) -> T? {
        let rootWithKey = rootForKeyPath(keyPath, with: container)
        guard let root = rootWithKey.root, let retValue = root[rootWithKey.key] else { return nil }
        
        if let _value = retValue as? T {
            cache.setValue(_value, for: keyPath)
            return _value
        }
            
        if let codableType = type as? Codable.Type, let _value = readCodableValue(with: retValue, type: codableType) {
            cache.setValue(_value, for: keyPath)
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
    
    private func setValue<T>(_ value: T?, for keys: [String], with container: inout [String: Any]) throws {
        var _keys = keys
        if keys.count > 1 {
            let key = _keys.removeFirst()
            if var _container = container[key] as? [String: Any] {
                try setValue(value, for: _keys, with: &_container)
                container[key] = _container
            } else if container[key] == nil {
                var _container: [String: Any] = [:]
                try setValue(value, for: _keys, with: &_container)
                container[key] = _container
            } else {
                throw PlistError.encodeTypeError
            }
        } else if let valueToSetted = value {
            if valueToSetted is PlistIsBasicCodableType {
                container[_keys.removeFirst()] = valueToSetted
            } else if let array = valueToSetted as? [Any], array.isPlistData {
                container[_keys.removeFirst()] = array
            } else if let dictionary = valueToSetted as? [String: Any], dictionary.isPlistData {
                container[_keys.removeFirst()] = dictionary
            } else if let codableValue = valueToSetted as? Codable {
                setCodableValue(codableValue, for: _keys.removeFirst(), with: &container)
            } else {
                throw PlistError.encodeTypeError
            }
        } else {
            container.removeValue(forKey: _keys.removeFirst())
        }
    }
    
    private func setCodableValue<T: Codable>(_ value: T, for key: String, with container: inout [String: Any]) {
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(value)
            let object = try PropertyListSerialization.propertyList(from: data, format: nil)
            container[key] = object
        } catch {
            delegate?.plist(errorOccurred: .encode(error))
        }
    }
}
