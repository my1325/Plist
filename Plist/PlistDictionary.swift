//
//  PlistDictionary.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

private final class PlistDictionaryObserverWrapper: PlistDictionaryObserver {
    private(set) weak var target: PlistDictionaryObserver?
    init(target: PlistDictionaryObserver) {
        self.target = target
    }
    
    var isNil: Bool { target == nil }
    
    func plistDictionary(_ plistDictionary: PlistDictionary, valueChangedWith keyPath: String, with value: Any?) {
        target?.plistDictionary(plistDictionary, valueChangedWith: keyPath, with: value)
    }
    
    class func ==(lhs: PlistDictionaryObserverWrapper, rhs: PlistDictionaryObserver) -> Bool {
        guard !lhs.isNil else { return false }
        return lhs.target! === rhs
    }
}

public protocol PlistDictionaryObserver: AnyObject {
    func plistDictionary(_ plistDictionary: PlistDictionary, valueChangedWith keyPath: String, with value: Any?)
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
}

public final class PlistDictionary: PlistContainer<[String: Any]> {
    fileprivate private(set) var observerList: [String: [PlistDictionaryObserverWrapper]] = [:]
    let lock = DispatchSemaphore(value: 1)
    public let cache: PlistDictionaryCacheCompatible
    public init(cacheStrategy: PlistDictionaryStrategy = .default, configuration: PlistContainerConfiguration) {
        switch cacheStrategy {
        case .none:
            self.cache = PlistDictionaryNoneCache()
        case .default:
            self.cache = PlistCache<String>(capacity: 20, queue: DispatchQueue(label: "com.ge.plist.cache.queue"), isAsynchornized: configuration.isASynchornizedCache)
        case let .custom(cache):
            self.cache = cache
        }
        super.init(container: [:], configuration: configuration)
    }
    
    public func addObserver(_ observer: PlistDictionaryObserver, for keyPath: String) {
        clearNilObserver()
        var _list = observerList[keyPath] ?? []
        _list.append(PlistDictionaryObserverWrapper(target: observer))
        observerList[keyPath] = _list
    }
    
    public func removeObserver(_ observer: PlistDictionaryObserver, for keyPath: String) {
        clearNilObserver()
        var _list = observerList[keyPath] ?? []
        if let index = _list.firstIndex(where: { $0 == observer }) {
            _list.remove(at: index)
        }
        observerList[keyPath] = _list
    }
    
    public subscript<T>(keyPath: String) -> T? {
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
            invokeObserverWithValue(value, for: keyPath)
        } catch {
            delegate?.plist(errorOccurred: .encodeTypeError)
        }
    }
    
    public func removeValue(_ keyPath: String) {
        lock.lock(); defer { lock.unlock() }
        var _container = container
        let keyQueue = keyPath.split(separator: ".").filter { !$0.isEmpty }.map { String($0) }
        if let key = keyQueue.last {
            do {
                _container.removeValue(forKey: key)
                try setContainer(_container)
                cache.setValue(nil, for: keyPath)
                invokeObserverWithValue(nil, for: keyPath)
            } catch {
                delegate?.plist(errorOccurred: .encodeTypeError)
            }
        }
    }
}

extension PlistDictionary {
    private func invokeObserverWithValue(_ value: Any?, for keyPath: String) {
        let _list = observerList[keyPath] ?? []
        for o in _list {
            guard !o.isNil else { continue }
            o.plistDictionary(self, valueChangedWith: keyPath, with: value)
        }
    }
    
    private func clearNilObserver() {
        for case (let key, var list) in observerList {
            for i in stride(from: list.count - 1, through: 0, by: -1) {
                if list[i].isNil {
                    list.remove(at: i)
                }
            }
            observerList[key] = list
        }
    }
    
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
