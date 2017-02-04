Promises in Swift
=================

[![Swift Version](https://img.shields.io/badge/swift-3.0-orange.svg)](https://swift.org)

A small and easy-to-use Promise class for Swift 3. Heavily inspired by [Promises/A+](https://promisesaplus.com/), familiar to all JavaScript developers by now.

## Install
Just copy the Promise.swift file to your (Xcode) project. I'm not going to create a Swift Package for one single Swift file. :)

## Usage
The Promise class is declared with a generic type. 
```swift
class Promise <T> {}
```
A Promise keeps hold of a value of type `T`, which is the value the Promise (your Promise) parses to the resolver(s).



#### Initialization
You initialize a Promise with a type and a function (closure) of type `(Resolve, Reject) -> ()`.
```swift
let promise = Promise<String> { resolve, reject in 
// Some heavy task.
}
```

Resolve and Reject are declared as:
```swift
typealias Resolve = (T?) -> ()
typealias Reject = (ErrorType?) -> ()
```

#### Resolve and reject
In your closure, you call the `resolve` function when your task was successful. Either give it a parameter of type `T?` or parse `nil`. Your call! 
When your task failed, call the `reject` function. Same story - but with a parameter of type `ErrorType?`.

The Promise runs asynchronously using GCD. Which means there's no need to wrap your function in `dispatch_async()` yourself. But the resolvers and rejects, however, run on the main thread! 

You can apply a Resolver using the Promise's instance method `.then(T?)`.
To apply a Rejector, use the `.catch(ErrorType?)` method.
```swift
Promise<Any> { resolve, reject in 
	// Some heavy task.
}.then { value in
	// Do something with value.   
}.catch { error in
	// Respond to the failure.
}
```
The methods of Promises are chainable! :-)


## Static methods
#### All
The static `all([Promise])` method returns a new Promise watching all Promises in the given array. An *all* Promise fails the moment one of its Promises calls its rejector. When all Promises succeed, the resolver is parsed an array of `[T?]` containing all the returned values of the Promises.
```swift
func createDownloadPromise(url: String) -> Promise<NSData> {
	// ...
}

Promise.all([
	createDownloadPromise("hello.jpg"),
	createDownloadPromise("world.jpg")
]).then { values in
	print("The following files have been downloaded: \(values)")
	// Prints: Optional([Optional("hello.jpg"), Optional("world.jpg")])
}.catch { _ in 
	print("Uh-oh! At least one Promise failed!")
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
