//
//  Plist.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

public protocol PlistContainerEncoder {
    func encode<Value>(_ value: Value) throws -> Data where Value : Encodable
}

public protocol PlistContainerDecoder {
    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable
}

public protocol PlistContainerDelegate: AnyObject {
    func plist(errorOccurred error: PlistError)
}

public struct PlistContainerConfiguration {
    public let path: String
    public let decoder: PlistContainerDecoder
    public let encoder: PlistContainerEncoder
    public let queue: DispatchQueue
}

open class PlistContainer<T> {
     
    @Atomic
    private(set) var container: T
    public let reader: DataReader
    public let writer: DataWriter
    public let configuration: PlistContainerConfiguration
    public init(container: T, configuration: PlistContainerConfiguration) {
        self.container = container
        self.reader = DataReader(path: configuration.path)
        self.writer = DataWriter(path: configuration.path)
        self.configuration = configuration
        self.reader.readData()
    }
    
    public weak var delegate: PlistContainerDelegate?
    
    open func setContainer(_ container: T) where T: Encodable {
        self.container = container
        self.writeToFile()
    }
   
    private func writeToFile() where T: Encodable {
        configuration.queue.async { [weak self] in
            guard let _self = self else { return }
            do {
                let data = try _self.configuration.encoder.encode(_self.container)
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
                if let DecodeT = T.self as? Decodable.Type {
                    let value = try _self.configuration.decoder.decode(DecodeT, from: data)
                    _self.container = value as! T
                } else {
                    _self.delegate?.plist(errorOccurred: .decodeTypeError)
                }
            } catch {
                _self.delegate?.plist(errorOccurred: .decode(error))
            }
        }
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
