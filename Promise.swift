/**
 *  Promise.swift
 *  v1.1
 *
 *  Created by Freek Zijlmans, 2016
 */

import Foundation


/**
 * Promise class for Swift.
 * Tries to follow the Promises/A+ specs. (https://promisesaplus.com/)
 * A Promise holds on to a value of type T.
 * Promises are executed in async mode. Whereas resolvers and rejections are executed on the main thread.
 */
class Promise<T> {
    
    typealias Resolve = (T?) -> ()
    typealias Reject = (ErrorType?) -> ()
    
    private (set) var resolvers: [Resolve] = []
    private (set) var fails: [Reject] = []
    private (set) var rejected = false
    private (set) var done = false
    
    private var value: T?
    private var error: ErrorType?
    
    init(_ promise: (Resolve, Reject) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            promise(self.resolveProxy, self.rejectProxy)
        }
    }
    
    
    
    // MARK: - Private proxies.
    private func resolveProxy(incoming: T?) {
        done = true
        value = incoming
        
        dispatch_async(dispatch_get_main_queue()) {
            for resolve in self.resolvers {
                resolve(incoming)
            }
            self.unbindAll()
        }
    }
    
    private func rejectProxy(error: ErrorType?) {
        done = true
        rejected = true
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
    func then(resolve: Resolve) -> Self {
        if !done {
            resolvers.append(resolve)
        }
        else if !rejected {
            dispatch_async(dispatch_get_main_queue()) {
                resolve(self.value)
            }
        }
        return self
    }
    
    /// Add resolve and reject handler.
    func then(resolve: Resolve, _ reject: Reject) -> Self {
        then(resolve)
        fail(reject)
        return self
    }
    
    /// Add reject handler.
    func fail(reject: Reject) -> Self {
        if !done {
            fails.append(reject)
        }
        else if rejected {
            dispatch_async(dispatch_get_main_queue()){
                reject(self.error)
            }
        }
        return self
    }
    
    /// Unbind all resolve and reject handlers.
    func unbindAll() {
        resolvers.removeAll()
        fails.removeAll()
    }
    
    
    
    // MARK: - Static
    /// Returns a Promise that watches multiple promises. Resolvers return an array of values.
    static func all(promises: [Promise]) -> Promise<[Any?]> {
        return Promise<[Any?]> { resolve, reject in
            var success = 0
            var returns = [Any?]()
            
            func done(incoming: Any?) {
                success += 1
                returns.append(incoming)
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
            
            for p in promises {
                p.then(done, failed)
            }
        }
    }
    
    /// Race for the first settled Promise.
    static func race(promises: [Promise]) -> Promise<Any> {
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
            
            for p in promises {
                p.then(done, done)
            }
        }
    }
    
    /// Returns a Promise that resolves with the given value.
    static func resolve(value: T) -> Promise<T> {
        return Promise<T> { res, _ in
            res(value)
        }
    }
    
    /// Returns a Promise that rejects with the given error.
    static func reject(reason: ErrorType?) -> Promise<T> {
        return Promise<T> { _, rej in
            rej(reason)
        }
    }
    
    
    
    // MARK: - Misc.
    deinit {
        unbindAll()
        value = nil
        error = nil
    }
    
}

