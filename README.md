Promises in Swift
=================

[![Swift Version](https://img.shields.io/badge/swift-3.0-orange.svg)](https://swift.org)

A small, quick 'n dirty, easy-to-use Promise class for Swift. Heavily inspired by [Promises/A+](https://promisesaplus.com/), familiar to JavaScripters alike.

## Install
Just copy the Promise.swift file to your (Xcode) project. I'm not going to create a Swift Package for one single Swift file. :)

## Usage
The Promise class is declared with a generic type. 
```swift
class Promise<T> {}
```
A Promise keeps hold of a value of type `T`, which is the value the Promise (your Promise) parses to the resolver(s).


#### Initialization
You initialize a Promise with a type and a function (closure) of type `(@escaping (T) -> (), @escaping (Error?) -> ()) -> ()`.
```swift
let promise = Promise<String> { resolve, reject in 
	// Either some heavy or async task.
}
```

#### Resolve and reject
In your closure, you call the `resolve` function when your task was successful. Either give it a parameter of type `T`. 
When your task failed, call the `reject` function. Same story - but with a parameter of type `Error?`.

Resolve and Reject are declared as:
```swift
typealias Resolve = (T?) -> ()
typealias Reject = (Error?) -> ()
```

The Promise runs asynchronously using GCD. Which means there's no need to wrap your function in `dispatch_async()` yourself. But the resolvers and rejects, however, run on the main thread! 

You can apply a Resolver using the Promise's instance method `.then(@escaping Resolve)`.
To apply a Rejector, use the `.catch(@escaping Reject)` method.
Use the `.finally(@escaping Final)` method to add a handler that will always be called. Finals are called after Resolvers and/or Rejectors.
```swift
Promise<Any> { resolve, reject in 
	// Some heavy task.
}.then { value in
	// Do something with value.   
}.catch { error in
	// Respond to the failure.
}.finally {
	// Always called.
}
```
The methods of Promises are chainable! :-)


## Static methods
#### All
The static `all([Promise<T>])` method returns a new Promise watching all Promises in the given array. An *all* Promise fails the moment one of its Promises calls its rejector. When all Promises succeed, the resolver is parsed an array of `[T]` containing all the returned values of the Promises. Position of the values correspond to the index of their respective Promise.
```swift
func createDownloadPromise(url: URL) -> Promise<(path: String, data: Data)> {
	// ...
}

Promise.all([
	createDownloadPromise(root + "/hello.jpg",
	createDownloadPromise(root + "/world.jpg")
]).then { values in
	for value in values {
		try value.data.write(to: URL(fileURLWithPath: value.path))
	}
}.catch { error in
	print("Uh-oh! At least one Promise failed! Error: \(error!)")
}
```

#### Race
The static `race([Promise])` method returns a new Promise which holds onto the first resolved Promise. A *race* Promise fails when all Promises called their rejector.


#### Downloading an image (iOS)
Here's an example of a Promise downloading an image. The example uses NSURLSession on iOS:
```swift
var image: UIImage?

Promise<Data> { resolve, reject in
	var request = URLRequest(URL: URL(string: "someimage.jpg")!)
	let session = URLSession.sharedSession()
	session.dataTask(with: request) { data, response, err in 
		if let dat = data, let img = UIImage(data: dat) {
			resolve(dat)
		}
		else {
			reject(err)
		}
	}.resume()
}.then { data in
	if let data = data {
		data.write(to: localURL)
		image = UIImage(data: data)
	}
}.catch { err in 
	if let error = err {
		print("Trouble downloading image. Error: \(error)")
	}
}
```
