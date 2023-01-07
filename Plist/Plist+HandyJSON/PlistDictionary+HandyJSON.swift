//
//  PlistDictionary+HandyJSON.swift
//  Plist
//
//  Created by my on 2023/1/7.
//

import Foundation
import HandyJSON
import Plist

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
    
    public func value<H>(for keyPath: String, with type: H.Type, defaultValue: H? = nil) -> H? where H: HandyJSON {
        let _value = value(for: keyPath, with: [String: Any].self, defaultValue: defaultValue?.toJSON())
        return H.deserialize(from: _value) ?? defaultValue
    }
    
    public func value<H>(for keyPath: String, with type: H.Type, defaultValue: H? = nil) -> H? where H: PlistHandyJSONType {
        if let _value = value(for: keyPath, with: [[String: Any]].self, defaultValue: defaultValue?.toPlistData() as? [[String : Any]]) {
            return H.fromPlistData(_value) ?? defaultValue
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

extension PlistArray {
    
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
