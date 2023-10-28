//
//  Plist.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation
#if canImport(DataWriter)
import DataWriter
#endif

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
        self.prepare()
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
    
    open func prepare() {
        if !FileManager.default.fileExists(atPath: configuration.path) {
            isPrepareToWrite = true
            if configuration.creatFileSynchorizedIfNotExists {
                do {
                    let data = try configuration.encoder.encodeContainer(container)
                    try data.write(to: URL(fileURLWithPath: configuration.path))
                } catch {
                    delegate?.plist(errorOccurred: .write(error))
                }
            } else {
                writeToFile()
            }
        } else {
            if configuration.readContainerSynchronize {
                readContainerSynchronize()
            } else {
                reader.readData()
            }
        }
    }

    private func writeToFile() {
        do {
            let data = try configuration.encoder.encodeContainer(container)
            writer.writeData(data)
        } catch {
            delegate?.plist(errorOccurred: .encode(error))
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
