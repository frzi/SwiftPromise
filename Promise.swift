/**
 *  Promise.swift
 *  v2.3.0
 *
 *  Promise class for Swift.
 *  Inspired by the Promises/A+ specs. (https://promisesaplus.com/)
 *  A Promise holds on to a value of type `T`.
 *  Promises are executed in async mode. Whereas resolvers and rejections are executed on the main thread.
 *
 *  Created by Freek Zijlmans, 2017
 */

import Dispatch

public enum PromiseStatus {
    case pending, resolved, rejected
}

open class Promise<T> {
    
    public typealias Resolve = (T) throws -> ()
    public typealias Reject = (Error?) -> ()
    public typealias Final = () -> ()
    
    private var resolvers: [Resolve] = []
    private var rejectors: [Reject] = []
    private var finals: [Final] = []
    private(set) var status = PromiseStatus.pending
    
    private var value: T!
    private var error: Error?
    
    public init(_ promise: @escaping (@escaping (T) -> (), @escaping Reject) -> ()) {
        DispatchQueue.global(qos: .default).async {
            promise(self.resolveProxy, self.rejectProxy)
        }
    }
    
    deinit {
        unbindAll()
        value = nil
        error = nil
    }
    
    
    // MARK: - Private proxies.
    private func resolveProxy(_ incoming: T) {
        status = .resolved
        value = incoming
        
        DispatchQueue.main.async {
            do {
                for resolve in self.resolvers {
                    try resolve(incoming)
                }
            }
            catch {
                self.callRejectors(error)
            }
            
            for final in self.finals {
                final()
            }
            self.unbindAll()
        }
    }
    
    private func rejectProxy(_ error: Error?) {
        status = .rejected
        self.error = error
        
        DispatchQueue.main.async {
            for reject in self.rejectors {
                reject(error)
            }
            for final in self.finals {
                final()
            }
            self.unbindAll()
        }
    }
    
    private func callRejectors(_ error: Error?) {
        self.error = error
        for rejector in rejectors {
            rejector(self.error)
        }
        rejectors.removeAll()
    }
    
    
    // MARK: - Then / catch / finally.
    /// Add resolve handler.
    @discardableResult
    open func then(_ resolve: @escaping Resolve) -> Self {
        if status == .pending {
            resolvers.append(resolve)
        }
        else if status == .resolved {
            DispatchQueue.main.async {
                do {
                    try resolve(self.value)
                }
                catch {
                    self.callRejectors(error)
                }
            }
        }
        return self
    }
    
    /// Add resolve and reject handler.
    @discardableResult
    open func then(_ resolve: @escaping Resolve, _ reject: @escaping Reject) -> Self {
        then(resolve).catch(reject)
        return self
    }
    
    /// Add reject handler.
    @discardableResult
    open func `catch`(_ reject: @escaping Reject) -> Self {
        if status == .pending {
            rejectors.append(reject)
        }
        else if status == .rejected {
            DispatchQueue.main.async {
                reject(self.error)
            }
        }
        return self
    }
    
    /// Add finally handler.
    @discardableResult
    open func finally(_ handler: @escaping Final) -> Self {
        if status == .pending {
            finals.append(handler)
        }
        else {
            DispatchQueue.main.async {
                handler()
            }
        }
        return self
    }
    
    /// Unbind all resolve and reject handlers.
    @discardableResult
    open func unbindAll() -> Self {
        resolvers.removeAll()
        rejectors.removeAll()
        finals.removeAll()
        return self
    }
    
    
    // MARK: - Static
    /// Returns a Promise that watches multiple promises. Resolvers get an array of values.
    open static func all(_ promises: [Promise<T>]) -> Promise<[T]> {
        return Promise<[T]> { resolve, reject in
            var settled = false
            var success = 0
            var returns = [T?](repeating: nil, count: promises.count)
            
            func failed(_ error: Error?) {
                if !settled {
                    settled = true
                    reject(error)
                }
            }
            
            func done(_ index: Int, _ incoming: T?) {
                success += 1
                returns[index] = incoming
                if success == promises.count {
                    settled = true
                    resolve(returns.flatMap { $0 })
                }
            }
            
            for (index, promise) in promises.enumerated() {
                promise.then({ obj in
                    done(index, obj)
                }, failed)
            }
        }
    }
    
    /// Race for the first settled Promise. Resolvers get the winning Promise.
    open static func race(_ promises: [Promise<T>]) -> Promise<Promise<T>> {
        return Promise<Promise<T>> { resolve, reject in
            var settled = false
            var failed = 0
            
            func fail(_ error: Error?) {
                failed += 1
                
                if failed == promises.count && !settled {
                    reject(nil) // All failed.
                }
            }
            
            for promise in promises {
                promise.then { _ in
                    if !settled {
                        settled = true
                        resolve(promise)
                    }
                }.catch(fail)
            }
        }
    }
    
    /// Returns a Promise that resolves with the given value.
    open static func resolve(_ value: T) -> Promise<T> {
        return Promise<T> { resolve, reject in
            resolve(value)
        }
    }
    
    /// Returns a Promise that rejects with the given error.
    open static func reject(_ reason: Error?) -> Promise<T> {
        return Promise<T> { _, reject in
            reject(reason)
        }
    }
    
}
