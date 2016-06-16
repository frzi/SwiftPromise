/**
 *  Promise.swift
 *  v2.0
 *
 *  Promise class for Swift 3.
 *  Tries to follow the Promises/A+ specs. (https://promisesaplus.com/)
 *  A Promise holds on to a value of type T.
 *  Promises are executed in async mode. Whereas resolvers and rejections are executed on the main thread.
 *
 *  Created by Freek Zijlmans, 2016
 */

import Dispatch


public enum PromiseStatus {
    case unresolved, resolved, rejected
}


public class Promise<T> {
    
    public typealias Resolve = (T?) -> ()
    public typealias Reject = (ErrorProtocol?) -> ()
    
    private (set) var resolvers: [Resolve] = []
    private (set) var fails: [Reject] = []
    private (set) var status = PromiseStatus.unresolved
    
    private var value: T?
    private var error: ErrorProtocol?
    
    init(_ promise: (Resolve, Reject) -> ()) {
        DispatchQueue.global(attributes: .qosDefault).async {
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
    
    private func rejectProxy(_ error: ErrorProtocol?) {
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
    public func then(_ resolve: Resolve) -> Promise {
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
    public func then(_ resolve: Resolve, _ reject: Reject) -> Promise {
        then(resolve)
        fail(reject)
        return self
    }
    
    /// Add reject handler.
    @discardableResult
    public func fail(_ reject: Reject) -> Promise {
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
    public func unbindAll() {
        resolvers.removeAll()
        fails.removeAll()
    }
    
    
    // MARK: - Static
    /// Returns a Promise that watches multiple promises. Resolvers return an array of values.
    public static func all(_ promises: [Promise]) -> Promise<[Any?]> {
        return Promise<[Any?]> { resolve, reject in
            var success = 0
            var returns = [Any?](repeating: nil, count: promises.count)
            
            func done(_ index: Int, _ incoming: Any?) {
                success += 1
                returns[index] = incoming
                if success == promises.count {
                    resolve(returns)
                }
            }
            
            func failed(_ error: ErrorProtocol?) {
                for promise in promises {
                    promise.unbindAll()
                }
                reject(error)
            }
            
            for (index, promise) in promises.enumerated() {
                promise.then({ obj in
                    done(index, obj)
                }, failed)
            }
        }
    }
    
    /// Race for the first settled Promise.
    public static func race(_ promises: [Promise]) -> Promise<Any> {
        return Promise<Any> { resolve, reject in
            var settled = false
            var failedCount = 0
            
            func done(_ incoming: Any) {
                if !settled {
                    settled = true
                    resolve(incoming)
                    
                    for promise in promises {
                        promise.unbindAll()
                    }
                }
            }
            
            func failed(_ incoming: ErrorProtocol?) {
                failedCount += 1
                if failedCount == promises.count {
                    reject(incoming) // Grab the last error.
                }
            }
            
            for promise in promises {
                promise.then(done, failed)
            }
        }
    }
    
    /// Returns a Promise that resolves with the given value.
    public static func resolve(_ value: T) -> Promise<T> {
        return Promise<T> { res, _ in
            res(value)
        }
    }
    
    /// Returns a Promise that rejects with the given error.
    public static func reject(_ reason: ErrorProtocol?) -> Promise<T> {
        return Promise<T> { _, rej in
            rej(reason)
        }
    }
    
}
