Promises in Swift
=================

Promises are dang great in JavaScript. What's dang great as well is Swift! So with that in mind, I decided to try and replicate Promises in Swift. Trying my best to stay close to the [Promises/A+](https://promisesaplus.com/) specs. There are plenty of other Promise and Future frameworks for Swift out there already. Some quite extensive, some pretty simple. Mine is of the simple variance.

### Install
Just copy the Promise.swift file to your Xcode project. Yeah, that's it! The beauty of Swift!

Usage
=====
The Promise class is declared with a generic type. 
```swift
class Promise <T> {}
```
A Promise keeps hold of a value of type `T`, which is the value the Promise (your Promise) parses to the resolver(s).



#### Initialization
You initialize a Promise with a type and a function/closure of type `(Resolve, Reject) -> ()`.
```swift
let promise = Promise<Any> { resolve, reject in 
  // ...
}
```

Resolve and Reject are declared as:
```swift
typealias Resolve = (T?) -> ()
typealias Reject = (ErrorType?) -> ()
```

The given function is run asynchronously, using GCD.