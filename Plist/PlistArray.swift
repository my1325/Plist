//
//  File.swift
//  Plist
//
//  Created by my on 2023/1/4.
//

import Foundation

private final class PlistArrayObserverWrapper: PlistArrayObserver {
    private(set) weak var target: PlistArrayObserver?
    init(target: PlistArrayObserver) {
        self.target = target
    }
    
    var isNil: Bool { target == nil }
    
    func plistDictionary(_ plistArray: PlistArray, valueChangedAt index: Int, with value: Any?) {
        target?.plistDictionary(plistArray, valueChangedAt: index, with: value)
    }
    
    class func ==(lhs: PlistArrayObserverWrapper, rhs: PlistArrayObserver) -> Bool {
        guard !lhs.isNil else { return false }
        return lhs.target! === rhs
    }
}

public protocol PlistArrayObserver: AnyObject {
    func plistDictionary(_ plistArray: PlistArray, valueChangedAt index: Int, with value: Any?)
}

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
}

public final class PlistArray: PlistContainer<[Any]> {
    fileprivate private(set) var observerList: [Int: [PlistArrayObserverWrapper]] = [:]
    public let cache: PlistArrayCacheCompatible
    public init(cacheStrategy: PlistArrayCacheStrategy = .default, configuration: PlistContainerConfiguration) {
        switch cacheStrategy {
        case .none:
            self.cache = PlistArrayNoneCache()
        case .default:
            self.cache = PlistCache<Int>(capacity: 20, queue: DispatchQueue(label: "com.ge.plist.cache.queue"), isAsynchornized: configuration.isASynchornizedCache)
        case let .custom(cache):
            self.cache = cache
        }
        super.init(container: [], configuration: configuration)
    }
    
    public var count: Int { container.count }
    
    public func addObserver(_ observer: PlistArrayObserver, at index: Int) {
        clearNilObserver()
        var _list = observerList[index] ?? []
        _list.append(PlistArrayObserverWrapper(target: observer))
        observerList[index] = _list
    }
    
    public func removeObserver(_ observer: PlistArrayObserver, at index: Int) {
        clearNilObserver()
        var _list = observerList[index] ?? []
        if let index = _list.firstIndex(where: { $0 == observer }) {
            _list.remove(at: index)
        }
        observerList[index] = _list
    }
    
    public subscript<T>(_ index: Int) -> T? {
        get { value(at: index, with: T.self) }
        set { setValue(newValue, at: index) }
    }
    
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
            invokeObserverWithValue(value, at: index)
        } catch {
            delegate?.plist(errorOccurred: PlistError.encodeTypeError)
        }
    }
    
    public func removeValue(_ at: Int) {
        precondition(at < count)
        do {
            var _container = container
            _container.remove(at: at)
            try setContainer(_container)
            cache.setValue(nil, for: at)
            invokeObserverWithValue(nil, at: at)
        } catch {
            delegate?.plist(errorOccurred: PlistError.encodeTypeError)
        }
    }
}

extension PlistArray {
    private func invokeObserverWithValue(_ value: Any?, at index: Int) {
        DispatchQueue.main.async {
            let _list = self.observerList[index] ?? []
            for o in _list {
                guard !o.isNil else { continue }
                o.plistDictionary(self, valueChangedAt: index, with: value)
            }
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
