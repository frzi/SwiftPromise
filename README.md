Promises in Swift
=================

[![Swift Version](https://img.shields.io/badge/swift-3.0-orange.svg)](https://swift.org)

Promises are dang great in JavaScript. What's dang great as well is Swift! So with that in mind, I decided to try and replicate Promises in Swift. Trying my best to stay close to the [Promises/A+](https://promisesaplus.com/) specs. There are plenty of other Promise and Future frameworks for Swift out there already. Some quite extensive, some pretty simple. Mine is of the simple variance.

## Install
Just copy the Promise.swift file to your Xcode project. Yeah, that's it! The beauty of Swift!

## TODO
Make the class Swift Package Manager ready. But not until `Dispatch` becomes available on Linux.

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
To apply a Rejector, use the `.fail(ErrorType?)` method.
```swift
Promise<Any> { resolve, reject in 
	// Some heavy task.
}.then { value in
	// Do something with value.   
}.fail { error in
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
]).then{ values in
	print("The following files have been downloaded: \(values)")
	// Prints: Optional([Optional("hello.jpg"), Optional("world.jpg")])
}.fail { _ in 
	print("Uh-oh! At least one Promise failed!")
}
```

#### Race


## Examples
In the `/examples` folder you'll find a small collection of examples for OS X / iOS. The examples can be run in Xcode or using the `swift` command in OS X's terminal.

#### Downloading an image (iOS)
Here's an example of a Promise downloading an image. The example uses NSURLSession on iOS:
```swift
var image: UIImage?

Promise<NSData> { resolve, reject in
	let request = NSURLRequest(URL: "someimage.jpg", cachePolicy: .ReloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
	let session = NSURLSession.sharedSession()
	session.dataTaskWithRequest(request) { data, response, err in 
		if let dat = data, img = UIImage(data: dat) {
			resolve(dat)
		}
		else {
			reject(err)
		}
	}.resume()
}.then{ data in
	data.writeToFile("imagesFolder")
	image = UIImage(data: data)
}.fail{ err in 
	if let error = err {
		print("Trouble downloading image. Error: \(error)")
	}
}
```
