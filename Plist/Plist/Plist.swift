//
//  Plist.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation
import FilePath
import DataWriter

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
    public let queue: DispatchQueue
    public let shouldCacheOriginData: Bool
    public let readContainerSynchronize: Bool
}

open class PlistContainer<T>: PlistContainerDelegate {
    @Atomic
    private var _container: T
    public var container: T { _container }
    
    @Atomic
    open private(set) var isPrepareToWrite: Bool = false
    public let reader: DataReader
    public let writer: DataWriter
    public let configuration: PlistContainerConfiguration
    public init(container: T, configuration: PlistContainerConfiguration) {
        self._container = container
        self.reader = DataReader(path: configuration.path)
        self.writer = DataWriter(path: configuration.path)
        self.configuration = configuration
        self.delegate = self
        if configuration.readContainerSynchronize {
            readContainerSynchronize()
        } else {
            reader.readData()
        }
    }

    public weak var delegate: PlistContainerDelegate?

    open func setContainer(_ container: T) throws {
        if isPrepareToWrite {
            _container = container
            writeToFile()
        } else {
            throw PlistError.notPrepared
        }
    }

    @discardableResult
    open func readContainerSynchronize() -> T? {
        do {
            let data = try reader.readDataSynchronize()
            return readData(data)
        } catch {
            delegate?.plist(errorOccurred: .read(error))
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
    
    @discardableResult
    private func readData(_ data: Data) -> T? {
        do {
            let value = try configuration.decoder.decodeContainer(T.self, from: data)
            didReadData(value)
            return value
        } catch {
            delegate?.plist(errorOccurred: .decode(error))
            return nil
        }
    }

    open func didReadData(_ data: T) {
        isPrepareToWrite = true 
        if configuration.shouldCacheOriginData {
            _container = data
        }
    }

    public func plist(errorOccurred error: PlistError) {
        error.logInDebug()
    }
}

extension PlistContainer: DataReaderDelegate, DataWriterDelegate {
    public func reader(_ reader: DataReader, errorOccurredWhenRead error: Error) {
        delegate?.plist(errorOccurred: .read(error))
    }
    
    public func writer(_ writer: DataWriter, errorOccurredWhenWrite error: Error) {
        delegate?.plist(errorOccurred: .write(error))
    }
    
    public func reader(_ reader: DataReader, readData data: Data) {
        readData(data)
    }
}
