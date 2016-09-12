/**
 *  Promise.swift
 *  v2.1.0
 *
 *  Promise class for Swift.
 *  Tries to follow the Promises/A+ specs. (https://promisesaplus.com/)
 *  A Promise holds on to a value of type `T`.
 *  Promises are executed in async mode. Whereas resolvers and rejections are executed on the main thread.
 *
 *  Created by Freek Zijlmans, 2016
 */

import Dispatch

public enum PromiseStatus {
    case pending, resolved, rejected
}

open class Promise<T> {
    
    public typealias Resolve = (T?) -> ()
    public typealias Reject = (Error?) -> ()
    
    private (set) var resolvers: [Resolve] = []
    private (set) var fails: [Reject] = []
    private (set) var status = PromiseStatus.pending
    
    private var value: T?
    private var error: Error?
    
    public init(_ promise: @escaping (@escaping Resolve, @escaping Reject) -> ()) {
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
    private func resolveProxy(_ incoming: T?) {
        status = .resolved
        value = incoming
        
        DispatchQueue.main.async {
            for resolve in self.resolvers {
                resolve(incoming)
            }
            self.unbindAll()
        }
    }
    
    private func rejectProxy(_ error: Error?) {
        status = .rejected
        self.error = error
        
        DispatchQueue.main.async {
            for reject in self.fails {
                reject(error)
            }
            self.unbindAll()
        }
    }
    
    
    // MARK: - Then / fail
    /// Add resolve handler.
    @discardableResult
    open func then(_ resolve: @escaping Resolve) -> Self {
        if status == .unresolved {
            resolvers.append(resolve)
        }
        else if status == .resolved {
            DispatchQueue.main.async {
                resolve(self.value)
            }
        }
        return self
    }
    
    /// Add resolve and reject handler.
    @discardableResult
    open func then(_ resolve: @escaping Resolve, _ reject: @escaping Reject) -> Self {
        then(resolve)
        fail(reject)
        return self
    }
    
    /// Add reject handler.
    @discardableResult
    open func fail(_ reject: @escaping Reject) -> Self {
        if status == .unresolved {
            fails.append(reject)
        }
        else if status == .rejected {
            DispatchQueue.main.async {
                reject(self.error)
            }
        }
        return self
    }
    
    /// Unbind all resolve and reject handlers.
    @discardableResult
    open func unbindAll() -> Self {
        resolvers.removeAll()
        fails.removeAll()
        return self
    }
    
    
    // MARK: - Static
    /// Returns a Promise that watches multiple promises. Resolvers get an array of values.
    open static func all(_ promises: [Promise]) -> Promise<[Any?]> {
        return Promise<[Any?]> { resolve, reject in
            var settled = false
            var success = 0
            var returns = [Any?](repeating: nil, count: promises.count)
            
            func done(_ index: Int, _ incoming: Any?) {
                success += 1
                returns[index] = incoming
                if success == promises.count {
                    settled = true
                    resolve(returns)
                }
            }
            
            func failed(_ error: Error?) {
                if !settled {
                    settled = true
                    reject(error)
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
                    }.fail(fail)
            }
        }
    }
    
    /// Returns a Promise that resolves with the given value.
    open static func resolve(_ value: T) -> Promise<T> {
        return Promise<T> { res, _ in
            res(value)
        }
    }
    
    /// Returns a Promise that rejects with the given error.
    open static func reject(_ reason: Error?) -> Promise<T> {
        return Promise<T> { _, rej in
            rej(reason)
        }
    }
    
}
