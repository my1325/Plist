//
//  PlistDictionary.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

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
    case custom(PlistDictionaryCacheCompatible)
    
    var cache: PlistDictionaryCacheCompatible {
        switch self {
        case .none: return PlistDictionaryCacheEmpty()
        case let .custom(cache): return cache
        }
    }
}

public extension PlistContainerConfiguration {
    static func plistWithPath(_ path: String, queue: DispatchQueue) -> PlistContainerConfiguration {
        let decoder = PlistDictionaryCoder()
        let encoder = PlistDictionaryCoder()
        return PlistContainerConfiguration(path: .file(file: path), decoder: decoder, encoder: encoder, queue: queue, shouldCacheOriginData: true)
    }
}

public let plist_run_queue = "com.ge.plist.run.queue"
public final class PlistDictionary: PlistContainer<[String: Any]> {
    let cache: PlistDictionaryCacheCompatible
    init(cacheStrategy: PlistDictionaryStrategy = .none, configuration: PlistContainerConfiguration) {
        self.cache = cacheStrategy.cache
        super.init(container: [:], configuration: configuration)
    }
    
    public subscript<T: Codable>(keyPath: String) -> T? {
        get { value(for: keyPath, with: T.self) }
        set { setValue(newValue, for: keyPath) }
    }
    
    public func value<T: Codable>(for keyPath: String, with type: T.Type, defaultValue: T? = nil) -> T? {
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
    
    public func setValue<T: Codable>(_ value: T?, for keyPath: String) {
        cache.setValue(value, for: keyPath)
        var _container = container
        let keyQueue = keyPath.split(separator: ".").filter { !$0.isEmpty }.map { String($0) }
        setValue(value, for: keyQueue, with: &_container)
        setContainer(_container)
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
    
    private func readValue<T: Codable>(for keyPath: String, with type: T.Type, from container: [String: Any]) -> T? {
        let rootWithKey = rootForKeyPath(keyPath, with: container)
        guard let root = rootWithKey.root, let retValue = root[rootWithKey.key] else { return nil }
        
        if let _value = retValue as? T {
            cache.setValue(_value, for: keyPath)
            return _value
        }
            
        if let _value = readCodableValue(with: retValue, type: type) {
            cache.setValue(_value, for: keyPath)
            return _value
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
    
    private func setValue<T: Codable>(_ value: T?, for keys: [String], with container: inout [String: Any]) {
        var _keys = keys
        if keys.count > 1 {
            let key = _keys.removeFirst()
            if var _container = container[key] as? [String: Any] {
                setValue(value, for: _keys, with: &_container)
                container[key] = _container
            } else if container[key] == nil {
                var _container: [String: Any] = [:]
                setValue(value, for: _keys, with: &_container)
                container[key] = _container
            } else {
                delegate?.plist(errorOccurred: .encodeTypeError)
                return
            }
        } else if let valueToSetted = value {
            if valueToSetted is PlistIsBasicCodableType {
                container[_keys.removeFirst()] = valueToSetted
            } else {
                setCodableValue(valueToSetted, for: _keys.removeFirst(), with: &container)
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
