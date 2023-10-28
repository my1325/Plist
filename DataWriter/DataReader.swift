//
//  DataReader.swift
//  Plist
//
//  Created by my on 2022/12/21.
//

import Foundation

public protocol DataReaderDelegate: AnyObject {
    func reader(_ reader: DataReader, errorOccurredWhenRead error: Error)
    func reader(_ reader: DataReader, readData data: Data)
}

public let plist_reader_queue = "com.ge.plist.read.queue"
public final class DataReader {
    public let path: String
    public let queue: DispatchQueue
    public init(path: String, queue: DispatchQueue = DispatchQueue(label: plist_reader_queue, qos: .background)) {
        self.path = path
        self.queue = queue
    }

    public weak var delegate: DataReaderDelegate?
    public func readDataSynchronize() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }

    public func readData() {
        self.queue.async { [weak self] in
            guard let _self = self else { return }
            do {
                let data = try _self.readDataSynchronize()
                _self.delegate?.reader(_self, readData: data)
            } catch {
                _self.delegate?.reader(_self, errorOccurredWhenRead: error)
            }
        }
    }
}
