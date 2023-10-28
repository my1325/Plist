//
//  PlistDictionary+HandyJSON.swift
//  Plist
//
//  Created by my on 2023/1/7.
//

import Foundation
import HandyJSON
import Combine
#if canImport(Plist)
import Plist
#endif

public protocol PlistHandyJSONType {
    func toPlistData() -> Any
    
    static func fromPlistData(_ data: Any) -> Self?
}

extension Array: PlistHandyJSONType where Element: HandyJSON {
    public func toPlistData() -> Any {
        self.toJSON().filter({ $0 != nil }).map({ $0! })
    }
    
    public static func fromPlistData(_ data: Any) -> Self? {
        if let _array = data as? [[String: Any]] {
            return self.deserialize(from: _array)?.filter({ $0 != nil }).map({ $0! })
        } else {
            return nil
        }
    }
}

extension PlistDictionary {
    
    subscript<T>(dynamicMember dynamicMember: String) -> T? where T: HandyJSON {
        get { self[dynamicMember] }
        set { self[dynamicMember] = newValue }
    }
    
    public subscript<T>(keyPath: String, default: T? = nil) -> T? where T: HandyJSON {
        get { value(for: keyPath, with: T.self, defaultValue: `default`) }
        set { setValue(newValue, for: keyPath) }
    }
    
    public subscript<T>(keyPath: String, default: T? = nil) -> T? where T: PlistHandyJSONType {
        get { value(for: keyPath, with: T.self, defaultValue: `default`) }
        set { setValue(newValue, for: keyPath) }
    }
    
    public func value<T>(for keyPath: String, with type: T.Type, defaultValue: T? = nil) -> T? where T: HandyJSON {
        let _value = value(for: keyPath, with: [String: Any].self, defaultValue: defaultValue?.toJSON())
        return T.deserialize(from: _value) ?? defaultValue
    }
    
    public func value<T>(for keyPath: String, with type: T.Type, defaultValue: T? = nil) -> T? where T: PlistHandyJSONType {
        if let _value = value(for: keyPath, with: [[String: Any]].self, defaultValue: defaultValue?.toPlistData() as? [[String : Any]]) {
            return T.fromPlistData(_value) ?? defaultValue
        } else {
            return defaultValue
        }
    }
    
    public func setValue<T>(_ value: T?, for keyPath: String) where T: HandyJSON {
        let plistData = value?.toJSON()
        setValue(plistData, for: keyPath)
    }
    
    public func setValue<T>(_ value: T?, for keyPath: String) where T: PlistHandyJSONType {
        let plistData = value?.toPlistData()
        setValue(plistData, for: keyPath)
    }
}

fileprivate class _PlistDictionaryHandJSONObserver<T: HandyJSON>: PlistDictionaryObserver {
    var callback: ((T?) -> Void)?
    let keyPath: String
    init(_ keyPath: String) {
        self.keyPath = keyPath
    }
    
    func plistDictionary(_ plistDictionary: PlistDictionary, valueChangedWith keyPath: String, with value: Any?) {
        guard keyPath == self.keyPath else { return }
        let _value: T? = (value as? T) ?? plistDictionary[keyPath]
       callback?(_value)
    }
}

fileprivate final class _PlistDictionaryHandJSONPublisher<T: HandyJSON>: _PlistDictionaryHandJSONObserver<T>, Publisher {
    typealias Output = T?
    typealias Failure = Never
    
    private final class _PlistDictionaryHandJSONObserverSubcription<T: HandyJSON>: Subscription {
        let keyPath: String
        let subscriber: AnySubscriber<T?, Never>
        private var _parent: _PlistDictionaryHandJSONObserver<T>?
        init<S: Subscriber>(_ subscriber: S, keyPath: String, observer: _PlistDictionaryHandJSONObserver<T>) where S.Failure == Never, S.Input == T? {
            self.keyPath = keyPath
            self.subscriber = AnySubscriber(subscriber)
            self._parent = observer
            observer.callback = { [weak self] in
                _ = self?.subscriber.receive($0)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            _parent = nil
            _parent?.callback = nil
        }
    }
    
    init(keyPath: String, type: T.Type) {
        super.init(keyPath)
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, T? == S.Input {
        let subscription = _PlistDictionaryHandJSONObserverSubcription(subscriber, keyPath: keyPath, observer: self)
        subscriber.receive(subscription: subscription)
    }
}

extension PlistDictionary {
    public func observe<T: HandyJSON>(_ keyPath: String, type: T.Type) -> AnyPublisher<T?, Never> {
        let plistDictionaryPublisher = _PlistDictionaryHandJSONPublisher(keyPath: keyPath, type: type)
        addObserver(plistDictionaryPublisher, for: keyPath)
        return plistDictionaryPublisher
            .eraseToAnyPublisher()
    }
}

@propertyWrapper
public final class DefaultPlistHandyJSONWrapper<T: HandyJSON> {
    
    let keyPath: String
    let defaultValue: T?
    public init(keyPath: String, defaultValue: T? = nil) {
        self.keyPath = keyPath
        self.defaultValue = defaultValue
    }
    
    public var projectedValue: PassthroughSubject<T?, Never> = PassthroughSubject()
        
    public var wrappedValue: T? {
        get { PlistDictionary.default.value(for: keyPath, with: T.self, defaultValue: defaultValue) }
        set {
            PlistDictionary.default.setValue(newValue, for: keyPath)
            projectedValue.send(newValue)
        }
    }
}

extension PlistArray {
    
    public subscript<T>(_ index: Int) -> T? where T: HandyJSON {
        get { value(at: index, with: T.self) }
        set { setValue(newValue, at: index) }
    }
    
    public subscript<T>(_ index: Int) -> T? where T: PlistHandyJSONType {
        get { value(at: index, with: T.self) }
        set { setValue(newValue, at: index) }
    }
    
    public func value<T>(at index: Int, with type: T.Type, defaultValue: T? = nil) -> T? where T: HandyJSON {
        let value = value(at: index, with: [String: Any].self, defaultValue: defaultValue?.toJSON())
        return T.deserialize(from: value) ?? defaultValue
    }
    
    public func value<T>(at index: Int, with type: T.Type, defaultValue: T? = nil) -> T? where T: PlistHandyJSONType {
        if let value = value(at: index, with: [[String: Any]].self, defaultValue: defaultValue?.toPlistData() as? [[String : Any]]) {
            return T.fromPlistData(value) ?? defaultValue
        } else {
            return defaultValue
        }
    }
    
    public func appendValue<T>(_ value: T) where T: HandyJSON {
        let _value = value.toJSON()
        appendValue(_value)
    }
    
    public func appendValue<T>(_ value: T) where T: PlistHandyJSONType {
        let _value = value.toPlistData()
        appendValue(_value)
    }
    
    public func setValue<T>(_ value: T?, at index: Int) where T: HandyJSON {
        let _value = value?.toJSON()
        setValue(_value, at: index)
    }
    
    public func setValue<T>(_ value: T?, at index: Int) where T: PlistHandyJSONType {
        let _value = value?.toPlistData()
        setValue(_value, at: index)
    }
}
