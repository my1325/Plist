//
//  Atomic.swift
//  Plist
//
//  Created by my on 2022/12/10.
//

import Foundation

public protocol Lock {
    func lock()
    func unlock()
}

public extension Lock {
    func onLock<T>(_ closure: @escaping () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try closure()
    }
    
    func onLock<O, T>(owner: O, _ closure: @escaping (O) throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try closure(owner)
    }
}

extension DispatchSemaphore: Lock {
    public func lock() {
         wait()
    }
    
    public func unlock() {
        signal()
    }
}

@propertyWrapper
public final class Atomic<T> {
    let lock: Lock = DispatchSemaphore(value: 1)
    
    private var _value: T
    public init(wrappedValue value: T) {
        self._value = value
    }
    
    public var wrappedValue: T {
        get {
            lock.onLock(owner: self, { $0._value })
        } set {
            lock.onLock(owner: self, { $0._value = newValue })
        }
    }
}
