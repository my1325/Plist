//
//  Plist.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

public protocol PlistIsBasicCodableType {}
extension Int: PlistIsBasicCodableType {}
extension Double: PlistIsBasicCodableType {}
extension Bool: PlistIsBasicCodableType {}
extension String: PlistIsBasicCodableType {}
extension Data: PlistIsBasicCodableType {}
extension Date: PlistIsBasicCodableType {}
extension Array: PlistIsBasicCodableType where Element: PlistIsBasicCodableType {}
extension Dictionary: PlistIsBasicCodableType where Key == String, Value: PlistIsBasicCodableType {}

extension Array where Element == Any {
    public var isPlistData: Bool {
        reduce(true, {
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
        })
    }
}

extension Dictionary where Key == String, Value == Any {
    public var isPlistData: Bool {
        reduce(true, {
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
        })
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
    public let queue: DispatchQueue
    public let shouldCacheOriginData: Bool
}

open class PlistContainer<T>: PlistContainerDelegate {
    @Atomic
    private var _container: T
    public var container: T {
        PlistError.notPrepared.fatalError(condition: true)
        return _container
    }

    public let reader: DataReader
    public let writer: DataWriter
    public let configuration: PlistContainerConfiguration
    public init(container: T, configuration: PlistContainerConfiguration) {
        self._container = container
        self.reader = DataReader(path: configuration.path)
        self.writer = DataWriter(path: configuration.path)
        self.configuration = configuration
        self.delegate = self
        self._container = readContainerSynchronize() ?? container
    }

    public weak var delegate: PlistContainerDelegate?

    open func setContainer(_ container: T) {
        _container = container
        writeToFile()
    }

    open func readContainerSynchronize() -> T? {
        do {
            if let data = reader.readDataSynchronize() {
                let value = try configuration.decoder.decodeContainer(T.self, from: data)
                if configuration.shouldCacheOriginData {
                    _container = value
                }
                didReadData(value)
                return value
            }
            return nil
        } catch {
            delegate?.plist(errorOccurred: .decode(error))
            return nil
        }
    }

    private func writeToFile() {
        configuration.queue.async { [weak self] in
            guard let _self = self else { return }
            do {
                let data = try _self.configuration.encoder.encodeContainer(_self.container)
                _self.writer.writeData(data)
            } catch {
                _self.delegate?.plist(errorOccurred: .encode(error))
            }
        }
    }

    private func readData(_ data: Data) {
        configuration.queue.async { [weak self] in
            guard let _self = self else { return }
            do {
                let value = try _self.configuration.decoder.decodeContainer(T.self, from: data)
                if _self.configuration.shouldCacheOriginData {
                    _self._container = value
                }
                _self.didReadData(value)
            } catch {
                _self.delegate?.plist(errorOccurred: .decode(error))
            }
        }
    }

    open func didReadData(_ data: T) {}
    
    public func plist(errorOccurred error: PlistError) {
        error.logInDebug()
    }
}

extension PlistContainer: DataReaderDelegate, DataWriterDelegate {
    public func reader(_ reader: DataReader, readData data: Data) {
        readData(data)
    }

    public func reader(_ reader: DataReader, errorOccurredWhenRead error: PlistError) {
        delegate?.plist(errorOccurred: error)
    }

    public func writer(_ writer: DataWriter, errorOccurredWhenWrite error: PlistError) {
        delegate?.plist(errorOccurred: error)
    }
}
