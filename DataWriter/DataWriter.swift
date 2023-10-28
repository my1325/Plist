//
//  Plist.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import Foundation

public protocol DataWriterDelegate: AnyObject {
    func writer(_ writer: DataWriter, errorOccurredWhenWrite error: Error)
}

public let plist_writer_queue = "com.ge.plist.write.queue"
public final class DataWriter {
    public let path: String
    public let queue: DispatchQueue
    public init(path: String, queue: DispatchQueue = DispatchQueue(label: plist_writer_queue, qos: .background)) {
        self.path = path
        self.queue = queue
    }
    
    public weak var delegate: DataWriterDelegate?
    
    @Atomic
    private var dataNeedToWrite: Data?
    
    private var writeSignal = DispatchSemaphore(value: 0)
    public func writeData(_ data: Data) {
        addRunloopObserverIfNotAdd()
        openWriterIfNeeded()
        dataNeedToWrite = data
    }
    
    private var isWaitToWrite: Bool = false
    @Atomic
    private var _isOpened: Bool = false
    public var isOpened: Bool { _isOpened }
    
    private func openWriterIfNeeded() {
        guard !_isOpened else { return }
        _isOpened = true
        queue.async { [weak self] in
            while self?.isOpened == true {
                self?.isWaitToWrite = true
                self?.writeSignal.wait()
                self?.isWaitToWrite = false
                if let _self = self, let _data = _self.dataNeedToWrite {
                    do {
                        try _data.write(to: URL(fileURLWithPath: _self.path))
                        _self.dataNeedToWrite = nil
                    } catch {
                        self?.delegate?.writer(_self, errorOccurredWhenWrite: error)
                    }
                }
            }
        }
    }
    
    @Atomic
    private var isAddRunloopObserver: Bool = false
    private lazy var runloopObserver: CFRunLoopObserver! = {
        let callout: @convention(c) (CFRunLoopObserver?, CFRunLoopActivity, UnsafeMutableRawPointer?) -> Void = { observer, activity, context in
            if let _context = context {
                let plistWriter: DataWriter = Unmanaged.fromOpaque(_context).takeUnretainedValue()
                plistWriter._runloopCallout(observer, activity)
            }
        }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        var context = CFRunLoopObserverContext(version: 0, info: pointer, retain: nil, release: nil, copyDescription: nil)
        let observer = CFRunLoopObserverCreate(nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0, callout, &context)
        return observer
    }()
    
    private func addRunloopObserverIfNotAdd() {
        guard !isAddRunloopObserver else { return }
        isAddRunloopObserver = true
        let runloop = CFRunLoopGetMain()
        CFRunLoopAddObserver(runloop, runloopObserver, .commonModes)
    }
    
    private func _runloopCallout(_ observer: CFRunLoopObserver!, _ activity: CFRunLoopActivity) {
        if isWaitToWrite, writeSignal.signal() > 1 {
            writeSignal.wait()
        }
    }
    
    private func removeRunloopObserver() {
        guard isAddRunloopObserver else { return }
        let runloop = CFRunLoopGetMain()
        CFRunLoopRemoveObserver(runloop, runloopObserver, .commonModes)
    }
    
    private func closeWriter() {
        _isOpened = false
        if isWaitToWrite, writeSignal.signal() > 1 {
            writeSignal.wait()
        }
    }
    
    deinit {
        closeWriter()
        removeRunloopObserver()
    }
}
