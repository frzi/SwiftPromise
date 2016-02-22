/**
 *  Promise.swift
 *  v1.2.2
 *
 *  Promise class for Swift.
 *  Tries to follow the Promises/A+ specs. (https://promisesaplus.com/)
 *  A Promise holds on to a value of type T.
 *  Promises are executed in async mode. Whereas resolvers and rejections are executed on the main thread.
 *
 *  Created by Freek Zijlmans, 2016
 */

import Dispatch


public enum PromiseStatus {
    case Unresolved, Resolved, Rejected
}


public class Promise<T> {
    
    public typealias Resolve = (T?) -> ()
    public typealias Reject = (ErrorType?) -> ()
    
    private (set) var resolvers: [Resolve] = []
    private (set) var fails: [Reject] = []
    private (set) var status = PromiseStatus.Unresolved
    
    private var value: T?
    private var error: ErrorType?
    
    init(_ promise: (Resolve, Reject) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            promise(self.resolveProxy, self.rejectProxy)
        }
    }
    
    deinit {
        unbindAll()
        value = nil
        error = nil
    }
    
    
    // MARK: - Private proxies.
    private func resolveProxy(incoming: T?) {
        status = .Resolved
        value = incoming
        
        dispatch_async(dispatch_get_main_queue()) {
            for resolve in self.resolvers {
                resolve(incoming)
            }
            self.unbindAll()
        }
    }
    
    private func rejectProxy(error: ErrorType?) {
        status = .Rejected
        self.error = error
        
        dispatch_async(dispatch_get_main_queue()) {
            for reject in self.fails {
                reject(error)
            }
            self.unbindAll()
        }
    }
    
    
    // MARK: - Then / fail
    /// Add resolve handler.
    public func then(resolve: Resolve) -> Self {
        if status == .Unresolved {
            resolvers.append(resolve)
        }
        else if status == .Resolved {
            dispatch_async(dispatch_get_main_queue()) {
                resolve(self.value)
            }
        }
        return self
    }
    
    /// Add resolve and reject handler.
    public func then(resolve: Resolve, _ reject: Reject) -> Self {
        then(resolve)
        fail(reject)
        return self
    }
    
    /// Add reject handler.
    public func fail(reject: Reject) -> Self {
        if status == .Unresolved {
            fails.append(reject)
        }
        else if status == .Rejected {
            dispatch_async(dispatch_get_main_queue()) {
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
    public static func all(promises: [Promise]) -> Promise<[Any?]> {
        return Promise<[Any?]> { resolve, reject in
            var success = 0
            var returns = [Any?](count: promises.count, repeatedValue: nil)
            
            func done(index: Int, _ incoming: Any?) {
                success += 1
                returns[index] = incoming
                if success == promises.count {
                    resolve(returns)
                }
            }
            
            func failed(error: ErrorType?) {
                for p in promises {
                    p.unbindAll()
                }
                reject(error)
            }
                        
            for (index, promise) in promises.enumerate() {
                promise.then({ obj in
                    done(index, obj)
                }, failed)
            }
        }
    }
    
    /// Race for the first settled Promise.
    public static func race(promises: [Promise]) -> Promise<Any> {
        return Promise<Any> { resolve, reject in
            var settled = false
            
            func done(incoming: Any) {
                if !settled {
                    settled = true
                    resolve(incoming)
                    
                    for p in promises {
                        p.unbindAll()
                    }
                }
            }
            
            for promise in promises {
                promise.then(done, done)
            }
        }
    }
    
    /// Returns a Promise that resolves with the given value.
    public static func resolve(value: T) -> Promise<T> {
        return Promise<T> { res, _ in
            res(value)
        }
    }
    
    /// Returns a Promise that rejects with the given error.
    public static func reject(reason: ErrorType?) -> Promise<T> {
        return Promise<T> { _, rej in
            rej(reason)
        }
    }
    
}