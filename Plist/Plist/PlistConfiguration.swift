//
//  PlistConfiguration.swift
//  Plist
//
//  Created by my on 2023/1/7.
//

import Foundation
import FilePath

public protocol PlistIsBasicCodableType {}
extension Int: PlistIsBasicCodableType {}
extension Double: PlistIsBasicCodableType {}
extension Bool: PlistIsBasicCodableType {}
extension String: PlistIsBasicCodableType {}
extension Data: PlistIsBasicCodableType {}
extension Date: PlistIsBasicCodableType {}
extension Array: PlistIsBasicCodableType where Element: PlistIsBasicCodableType {}
extension Dictionary: PlistIsBasicCodableType where Key == String, Value: PlistIsBasicCodableType {}

public extension Array where Element == Any {
    var isPlistData: Bool {
        reduce(true) {
            if $1 is PlistIsBasicCodableType {
                return $0
            }

            if let array = $1 as? [Any] {
                return $0 && array.isPlistData
            }

            if let dictionary = $1 as? [String: Any] {
                return $0 && dictionary.isPlistData
            }

            return false
        }
    }
}

public extension Dictionary where Key == String, Value == Any {
    var isPlistData: Bool {
        reduce(true) {
            if $1.value is PlistIsBasicCodableType {
                return $0
            }

            if let array = $1.value as? [Any] {
                return $0 && array.isPlistData
            }

            if let dictionary = $1.value as? [String: Any] {
                return $0 && dictionary.isPlistData
            }

            return false
        }
    }
}

public protocol PlistContainerEncoder {
    func encodeContainer<T>(_ value: T) throws -> Data
}

public protocol PlistContainerDecoder {
    func decodeContainer<T>(_ type: T.Type, from data: Data) throws -> T
}

public protocol PlistContainerDelegate: AnyObject {
    func plist(errorOccurred error: PlistError)
}

public struct PlistContainerConfiguration {
    public let path: FilePath
    public let decoder: PlistContainerDecoder
    public let encoder: PlistContainerEncoder
    public let shouldCacheOriginData: Bool
    public let readContainerSynchronize: Bool
    public let creatFileSynchorizedIfNotExists: Bool
}

open class PlistDefaultCoder: PlistContainerEncoder, PlistContainerDecoder {
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

open class PlistJSONCoder: PlistContainerEncoder, PlistContainerDecoder {
    public func encodeContainer<T>(_ value: T) throws -> Data {
        if JSONSerialization.isValidJSONObject(value) {
            return try JSONSerialization.data(withJSONObject: value, options: .prettyPrinted)
        } else {
            throw PlistError.encodeTypeError
        }
    }
    
    public func decodeContainer<T>(_ type: T.Type, from data: Data) throws -> T {
        if let value = try JSONSerialization.jsonObject(with: data) as? T {
            return value
        } else {
            throw PlistError.decodeTypeError
        }
    }
}

public extension PlistContainerConfiguration {
    
    static func defaultPlistConfiguration(with path: FilePath, shouldCacheOriginData: Bool = true, readContainerSynchronize: Bool = true) -> PlistContainerConfiguration {
        let decoder = PlistDefaultCoder()
        let encoder = PlistDefaultCoder()
        return PlistContainerConfiguration(path: path, decoder: decoder, encoder: encoder, shouldCacheOriginData: shouldCacheOriginData, readContainerSynchronize: readContainerSynchronize, creatFileSynchorizedIfNotExists: true)
    }
    
    static func JSONPlistConfiguration(with path: FilePath, shouldCacheOriginData: Bool = true, readContainerSynchronize: Bool = true) -> PlistContainerConfiguration {
        let decoder = PlistJSONCoder()
        let encoder = PlistJSONCoder()
        return PlistContainerConfiguration(path: path, decoder: decoder, encoder: encoder, shouldCacheOriginData: shouldCacheOriginData, readContainerSynchronize: readContainerSynchronize, creatFileSynchorizedIfNotExists: true)
    }
}
