//
// Image downloader written in Swift for iOS, tvOS and macOS.
//
// https://github.com/evgenyneu/moa
//
// This file was automatically generated by combining multiple Swift source files.
//


// ----------------------------
//
// MoaError.swift
//
// ----------------------------

import Foundation

/**
 
 Errors reported by the moa downloader
 
*/
public enum MoaError: Error {
  /// Incorrect URL is supplied. Error code: 0.
  case invalidUrlString
  
  /// Response HTTP status code is not 200. Error code: 1.
  case httpStatusCodeIsNot200
  
  /// Response is missing Content-Type http header. Error code: 2.
  case missingResponseContentTypeHttpHeader
  
  /// Response Content-Type http header is not an image type. Error code: 3.
  case notAnImageContentTypeInResponseHttpHeader
  
  /// Failed to convert response data to UIImage. Error code: 4.
  case failedToReadImageData
  
  /// Simulated error used in unit tests. Error code: 5.
  case simulatedError
  
  /// A human-friendly error description.
  var localizedDescription: String {
    let comment = "Moa image downloader error"
  
    switch self {
    case .invalidUrlString:
      return NSLocalizedString("Invalid URL.", comment: comment)
    
    case .httpStatusCodeIsNot200:
      return NSLocalizedString("Response HTTP status code is not 200.", comment: comment)
      
    case .missingResponseContentTypeHttpHeader:
      return NSLocalizedString("Response HTTP header is missing content type.", comment: comment)
      
    case .notAnImageContentTypeInResponseHttpHeader:
      return NSLocalizedString("Response content type is not an image type. Content type needs to be  'image/jpeg', 'image/pjpeg', 'image/png' or 'image/gif'",
        comment: comment)
      
    case .failedToReadImageData:
      return NSLocalizedString("Could not convert response data to an image format.",
        comment: comment)
      
    case .simulatedError:
      return NSLocalizedString("Test error.", comment: comment)
    }
  }
  
  var code: Int {
    return (self as Error)._code
  }
}


// ----------------------------
//
// MoaHttp.swift
//
// ----------------------------

import Foundation

/**

Shortcut function for creating URLSessionDataTask.

*/
struct MoaHttp {
  static func createDataTask(_ url: String,
    onSuccess: @escaping (Data?, HTTPURLResponse)->(),
    onError: @escaping (Error?, HTTPURLResponse?)->()) -> URLSessionDataTask? {
      
    if let urlObject = URL(string: url) {
      return createDataTask(urlObject: urlObject, onSuccess: onSuccess, onError: onError)
    }
    
    // Error converting string to NSURL
    onError(MoaError.invalidUrlString, nil)
    return nil
  }
  
  private static func createDataTask(urlObject: URL,
    onSuccess: @escaping (Data?, HTTPURLResponse)->(),
    onError: @escaping (Error?, HTTPURLResponse?)->()) -> URLSessionDataTask? {
      
    return MoaHttpSession.session?.dataTask(with: urlObject) { (data, response, error) in
      if let httpResponse = response as? HTTPURLResponse {
        if error == nil {
          onSuccess(data, httpResponse)
        } else {
          onError(error, httpResponse)
        }
      } else {
        onError(error, nil)
      }
    }
  }
}


// ----------------------------
//
// MoaHttpImage.swift
//
// ----------------------------


import Foundation

/**

Helper functions for downloading an image and processing the response.

*/
struct MoaHttpImage {
  static func createDataTask(_ url: String,
    onSuccess: @escaping (MoaImage)->(),
    onError: @escaping (Error?, HTTPURLResponse?)->()) -> URLSessionDataTask? {
    
    return MoaHttp.createDataTask(url,
      onSuccess: { data, response in
        self.handleSuccess(data, response: response, onSuccess: onSuccess, onError: onError)
      },
      onError: onError
    )
  }
  
  static func handleSuccess(_ data: Data?,
    response: HTTPURLResponse,
    onSuccess: (MoaImage)->(),
    onError: (Error, HTTPURLResponse?)->()) {
      
    // Show error if response code is not 200
    if response.statusCode != 200 {
      onError(MoaError.httpStatusCodeIsNot200, response)
      return
    }
    
    // Ensure response has the valid MIME type
    if let mimeType = response.mimeType {
      if !validMimeType(mimeType) {
        // Not an image Content-Type http header
        let error = MoaError.notAnImageContentTypeInResponseHttpHeader
        onError(error, response)
        return
      }
    } else {
      // Missing Content-Type http header
      let error = MoaError.missingResponseContentTypeHttpHeader
      onError(error, response)
      return
    }
      
    if let data = data, let image = MoaImage(data: data) {
      onSuccess(image)
    } else {
      // Failed to convert response data to UIImage
      let error = MoaError.failedToReadImageData
      onError(error, response)
    }
  }
  
  private static func validMimeType(_ mimeType: String) -> Bool {
    let validMimeTypes = ["image/jpeg", "image/jpg", "image/pjpeg", "image/png", "image/gif"]
    return validMimeTypes.contains(mimeType)
  }
}


// ----------------------------
//
// MoaHttpImageDownloader.swift
//
// ----------------------------

import Foundation

final class MoaHttpImageDownloader: MoaImageDownloader {
  var task: URLSessionDataTask?
  var cancelled = false
  
  // When false - the cancel request will not be logged. It is used in order to avoid
  // loggin cancel requests after success or error has been received.
  var canLogCancel = true
  
  var logger: MoaLoggerCallback?
  
  
  init(logger: MoaLoggerCallback?) {
    self.logger = logger
  }
  
  deinit {
    cancel()
  }
  
  func startDownload(_ url: String, onSuccess: @escaping (MoaImage)->(),
    onError: @escaping (Error?, HTTPURLResponse?)->()) {
      
    logger?(.requestSent, url, nil, nil)
    
    cancelled = false
    canLogCancel = true
  
    task = MoaHttpImage.createDataTask(url,
      onSuccess: { [weak self] image in
        self?.canLogCancel = false
        self?.logger?(.responseSuccess, url, 200, nil)
        onSuccess(image)
      },
      onError: { [weak self] error, response in
        self?.canLogCancel = false
        
        if let currentSelf = self , !currentSelf.cancelled {
          // Do not report error if task was manually cancelled
          self?.logger?(.responseError, url, response?.statusCode, error)
          onError(error, response)
        }
      }
    )
      
    task?.resume()
  }
  
  func cancel() {
    if cancelled { return }
    cancelled = true
    
    task?.cancel()
    
    if canLogCancel {
      let url = task?.originalRequest?.url?.absoluteString ?? ""
      logger?(.requestCancelled, url, nil, nil)
    }
  }
}


// ----------------------------
//
// MoaHttpSession.swift
//
// ----------------------------

import Foundation

/// Contains functions for managing URLSession.
public struct MoaHttpSession {
  private static var currentSession: URLSession?
  
  static var session: URLSession? {
    get {
      if currentSession == nil {
        currentSession = createNewSession()
      }
    
      return currentSession
    }
    
    set {
      currentSession = newValue
    }
  }
  
  private static func createNewSession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    
    configuration.timeoutIntervalForRequest = Moa.settings.requestTimeoutSeconds
    configuration.timeoutIntervalForResource = Moa.settings.requestTimeoutSeconds
    configuration.httpMaximumConnectionsPerHost = Moa.settings.maximumSimultaneousDownloads
    configuration.requestCachePolicy = Moa.settings.cache.requestCachePolicy
    
    #if os(iOS) || os(tvOS)
      // Cache path is a directory name in iOS
      let cachePath = Moa.settings.cache.diskPath
    #elseif os(OSX)
      // Cache path is a disk path in OSX
      let cachePath = osxCachePath(Moa.settings.cache.diskPath)
    #endif
    
    let cache = URLCache(
      memoryCapacity: Moa.settings.cache.memoryCapacityBytes,
      diskCapacity: Moa.settings.cache.diskCapacityBytes,
      diskPath: cachePath)
    
    configuration.urlCache = cache
    
    return URLSession(configuration: configuration)
  }
  
  // Returns the cache path for OSX.
  private static func osxCachePath(_ dirName: String) -> String {
    var basePath = NSTemporaryDirectory()
    let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.applicationSupportDirectory,
      FileManager.SearchPathDomainMask.userDomainMask, true)
    
    if paths.count > 0 {
      basePath = paths[0]
    }
    
    return (basePath as NSString).appendingPathComponent(dirName)
  }
  
  static func cacheSettingsChanged(_ oldSettings: MoaSettingsCache) {
    if oldSettings != Moa.settings.cache {
      session = nil
    }
  }
  
  static func settingsChanged(_ oldSettings: MoaSettings) {
    if oldSettings != Moa.settings  {
      session = nil
    }
  }
  
  /// Calls `finishTasksAndInvalidate` on the current session. A new session will be created for future downloads.
  public static func clearSession() {
    currentSession?.finishTasksAndInvalidate()
    currentSession = nil
  }
}


// ----------------------------
//
// ImageView+moa.swift
//
// ----------------------------

import Foundation

private var xoAssociationKey: UInt8 = 0

/**

Image view extension for downloading images.

    let imageView = UIImageView()
    imageView.moa.url = "http://site.com/image.jpg"

*/
public extension MoaImageView {
  /**
  
  Image download extension.
  Assign its `url` property to download and show the image in the image view.
  
      // iOS
      let imageView = UIImageView()
      imageView.moa.url = "http://site.com/image.jpg"
  
      // OS X
      let imageView = NSImageView()
      imageView.moa.url = "http://site.com/image.jpg"
  
  */
  public var moa: Moa {
    get {
      if let value = objc_getAssociatedObject(self, &xoAssociationKey) as? Moa {
        return value
      } else {
        let moa = Moa(imageView: self)
        objc_setAssociatedObject(self, &xoAssociationKey, moa, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        return moa
      }
    }
    
    set {
      objc_setAssociatedObject(self, &xoAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }
  }
}


// ----------------------------
//
// MoaConsoleLogger.swift
//
// ----------------------------

import Foundation

/**

Logs image download requests, responses and errors to Xcode console for debugging.

Usage:

    Moa.logger = MoaConsoleLogger

*/
public func MoaConsoleLogger(_ type: MoaLogType, url: String, statusCode: Int?, error: Error?) {
  let text = MoaLoggerText(type, url: url, statusCode: statusCode, error: error)
  print(text)
}


// ----------------------------
//
// MoaLoggerCallback.swift
//
// ----------------------------

import Foundation

/**

A logger closure.

Parameters:

1. Type of the log.
2. URL of the request.
3. Http status code, if applicable.
4. Error object, if applicable. Read its localizedDescription property to get a human readable error description.

*/
public typealias MoaLoggerCallback = (MoaLogType, String, Int?, Error?)->()


// ----------------------------
//
// MoaLoggerText.swift
//
// ----------------------------

import Foundation

/**

A helper function that creates a human readable text from log arguments.

Usage:

    Moa.logger = { type, url, statusCode, error in

      let text = MoaLoggerText(type: type, url: url, statusCode: statusCode, error: error)
      // Log log text to your destination
    }

For logging into Xcode console you can use MoaConsoleLogger function.

    Moa.logger = MoaConsoleLogger

*/
public func MoaLoggerText(_ type: MoaLogType, url: String, statusCode: Int?,
  error: Error?) -> String {
  
  let time = MoaTime.nowLogTime
  var text = "[moa] \(time) "
  var suffix = ""
  
  switch type {
  case .requestSent:
    text += "GET "
  case .requestCancelled:
    text += "Cancelled "
  case .responseSuccess:
    text += "Received "
  case .responseError:
    text += "Error "
    
    if let statusCode = statusCode {
      text += "\(statusCode) "
    }
    
    if let error = error {
      if let moaError = error as? MoaError {
        suffix = moaError.localizedDescription
      } else {
        suffix = error.localizedDescription
      }
    }
  }
  
  text += url
  
  if suffix != "" {
    text += " \(suffix)"
  }
  
  return text
}


// ----------------------------
//
// MoaLogType.swift
//
// ----------------------------

/**

Types of log messages.

*/
public enum MoaLogType: Int{
  /// Request is sent
  case requestSent
  
  /// Request is cancelled
  case requestCancelled
  
  /// Successful response is received
  case responseSuccess
  
  /// Response error is received
  case responseError
}


// ----------------------------
//
// Moa.swift
//
// ----------------------------

#if os(iOS) || os(tvOS)
  import UIKit
  public typealias MoaImage = UIImage
  public typealias MoaImageView = UIImageView
#elseif os(OSX)
  import AppKit
  public typealias MoaImage = NSImage
  public typealias MoaImageView = NSImageView
#endif

/**
Downloads an image by url.

Setting `moa.url` property of an image view instance starts asynchronous image download using URLSession class.
When download is completed the image is automatically shown in the image view.

    // iOS
    let imageView = UIImageView()
    imageView.moa.url = "http://site.com/image.jpg"

    // OS X
    let imageView = NSImageView()
    imageView.moa.url = "http://site.com/image.jpg"


The class can be instantiated and used without an image view:

    let moa = Moa()
    moa.onSuccessAsync = { image in
      return image
    }
    moa.url = "http://site.com/image.jpg"

*/
public final class Moa {
  private var imageDownloader: MoaImageDownloader?
  private weak var imageView: MoaImageView?

  /// Image download settings.
  public static var settings = MoaSettings() {
    didSet {
      MoaHttpSession.settingsChanged(oldValue)
    }
  }
  
  /// Supply a callback closure for getting request, response and error logs
  public static var logger: MoaLoggerCallback?

  /**

  Instantiate Moa when used without an image view.

      let moa = Moa()
      moa.onSuccessAsync = { image in }
      moa.url = "http://site.com/image.jpg"

  */
  public init() { }

  init(imageView: MoaImageView) {
    self.imageView = imageView
  }

  /**

  Assign an image URL to start the download.
  When download is completed the image is automatically shown in the image view.

      imageView.moa.url = "http://mysite.com/image.jpg"

  Supply `onSuccessAsync` closure to receive an image when used without an image view:

      moa.onSuccessAsync = { image in
        return image
      }

  */
  public var url: String? {
    didSet {
      cancel()

      if let url = url {
        startDownload(url)
      }
    }
  }

  /**

  Cancels image download.

  Ongoing image download for the image view is *automatically* cancelled when:

  1. Image view is deallocated.
  2. New image download is started: `imageView.moa.url = ...`.

  Call this method to manually cancel the download.

      imageView.moa.cancel()

  */
  public func cancel() {
    imageDownloader?.cancel()
    imageDownloader = nil
  }
  
  /**
  
  The closure will be called after download finishes and before the image
  is assigned to the image view. The closure is called in the main queue.
  
  The closure returns an image that will be shown in the image view.
  Return nil if you do not want the image to be shown.
  
      moa.onSuccess = { image in
        // Image is received
        return image
      }
  
  */
  public var onSuccess: ((MoaImage)->(MoaImage?))?

  /**

  The closure will be called *asynchronously* after download finishes and before the image
  is assigned to the image view.

  This is a good place to manipulate the image before it is shown.

  The closure returns an image that will be shown in the image view.
  Return nil if you do not want the image to be shown.

      moa.onSuccessAsync = { image in
        // Manipulate the image
        return image
      }

  */
  public var onSuccessAsync: ((MoaImage)->(MoaImage?))?

  /**
  
  The closure is called in the main queue if image download fails.
  [See Wiki](https://github.com/evgenyneu/moa/wiki/Moa-errors) for the list of possible error codes.
  
      onError = { error, httpUrlResponse in
        // Report error
      }
  
  */
  public var onError: ((Error?, HTTPURLResponse?)->())?
  
  /**

  The closure is called *asynchronously* if image download fails.
  [See Wiki](https://github.com/evgenyneu/moa/wiki/Moa-errors) for the list of possible error codes.

      onErrorAsync = { error, httpUrlResponse in
        // Report error
      }

  */
  public var onErrorAsync: ((Error?, HTTPURLResponse?)->())?
  
  
  /**
  
  Image that will be used if error occurs. The image will be assigned to the image view. Callbacks `onSuccess` and `onSuccessAsync` will  be called with the supplied image. Callbacks `onError` and `onErrorAsync` will also be called.
  
  */
  public var errorImage: MoaImage?
  
  /**
  
  A global error image that will be used if error occurs in any of the image downloads. The image will be assigned to the image view. Callbacks `onSuccess` and `onSuccessAsync` will  be called with the supplied image. Callbacks `onError` and `onErrorAsync` will also be called.
  
  */
  public static var errorImage: MoaImage?

  private func startDownload(_ url: String) {
    cancel()
    
    let simulatedDownloader = MoaSimulator.createDownloader(url)
    imageDownloader = simulatedDownloader ?? MoaHttpImageDownloader(logger: Moa.logger)
    let simulated = simulatedDownloader != nil
    
    imageDownloader?.startDownload(url,
      onSuccess: { [weak self] image in
        self?.handleSuccessAsync(image, isSimulated: simulated)
      },
      onError: { [weak self] error, response in
        self?.handleErrorAsync(error, response: response, isSimulated: simulated)
      }
    )
  }

  /**

  Called asynchronously by image downloader when image is received.
  
  - parameter image: Image received by the downloader.
  - parameter isSimulated: True if the image was supplied by moa simulator rather than real network.

  */
  private func handleSuccessAsync(_ image: MoaImage, isSimulated: Bool) {
    var imageForView: MoaImage? = image

    if let onSuccessAsync = onSuccessAsync {
      imageForView = onSuccessAsync(image)
    }

    if isSimulated {
      // Assign image in the same queue for simulated download to make unit testing simpler with synchronous code
      handleSuccessMainQueue(imageForView)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.handleSuccessMainQueue(imageForView)
      }
    }
  }
  
  /**
  
  Called by image downloader in the main queue when image is received.
  
  - parameter image: Image received by the downloader.
  
  */
  private func handleSuccessMainQueue(_ image: MoaImage?) {
    var imageForView: MoaImage? = image
    
    if let onSuccess = onSuccess, let image = image {
      imageForView = onSuccess(image)
    }
    
    imageView?.image = imageForView
  }
  
  /**
  
  Called asynchronously by image downloader if imaged download fails.
  
  - parameter error: Error object.
  - parameter response: HTTP response object, can be useful for getting HTTP status code.
  - parameter isSimulated: True if the image was supplied by moa simulator rather than real network.
  
  */
  private func handleErrorAsync(_ error: Error?, response: HTTPURLResponse?, isSimulated: Bool) {
    if let errorImage = globalOrInstanceErrorImage {
      handleSuccessAsync(errorImage, isSimulated: isSimulated)
    }
    
    onErrorAsync?(error, response)
    
    if let onError = onError {
      DispatchQueue.main.async {
        onError(error, response)
      }
    }
  }
  
  private var globalOrInstanceErrorImage: MoaImage? {
    get {
      return errorImage ?? Moa.errorImage
    }
  }
}


// ----------------------------
//
// MoaImageDownloader.swift
//
// ----------------------------

import Foundation

/// Downloads an image.
protocol MoaImageDownloader {
  func startDownload(_ url: String, onSuccess: @escaping (MoaImage)->(),
    onError: @escaping (Error?, HTTPURLResponse?)->())
  
  func cancel()
}


// ----------------------------
//
// MoaSettings.swift
//
// ----------------------------


/**

Settings for Moa image downloader.

*/
public struct MoaSettings {
  /// Settings for caching of the images.
  public var cache = MoaSettingsCache() {
    didSet {
      MoaHttpSession.cacheSettingsChanged(oldValue)
    }
  }
  
  /// Timeout for image requests in seconds. This will cause a timeout if a resource is not able to be retrieved within a given timeout. Default timeout: 10 seconds.
  public var requestTimeoutSeconds: Double = 10
  
  /// Maximum number of simultaneous image downloads. Default: 4.
  public var maximumSimultaneousDownloads: Int = 4
}

func ==(lhs: MoaSettings, rhs: MoaSettings) -> Bool {
  return lhs.requestTimeoutSeconds == rhs.requestTimeoutSeconds
    && lhs.maximumSimultaneousDownloads == rhs.maximumSimultaneousDownloads
    && lhs.cache == rhs.cache
}

func !=(lhs: MoaSettings, rhs: MoaSettings) -> Bool {
  return !(lhs == rhs)
}


// ----------------------------
//
// MoaSettingsCache.swift
//
// ----------------------------

import Foundation

/**

Specify settings for caching of downloaded images.

*/
public struct MoaSettingsCache {
  /// The memory capacity of the cache, in bytes. Default value is 20 MB.
  public var memoryCapacityBytes: Int = 20 * 1024 * 1024
  
  /// The disk capacity of the cache, in bytes. Default value is 100 MB.
  public var diskCapacityBytes: Int = 100 * 1024 * 1024
  
  /**

  The caching policy for the image downloads. The default value is .useProtocolCachePolicy.
  
  * .useProtocolCachePolicy - Images are cached according to the the response HTTP headers, such as age and expiration date. This is the default cache policy.
  * .reloadIgnoringLocalCacheData - Do not cache images locally. Always downloads the image from the source.
  * .returnCacheDataElseLoad - Loads the image from local cache regardless of age and expiration date. If there is no existing image in the cache, the image is loaded from the source.
  * .returnCacheDataDontLoad - Load the image from local cache only and do not attempt to load from the source.

  */
  public var requestCachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy
  
  /**
  
  The name of a subdirectory of the application’s default cache directory
  in which to store the on-disk cache.
  
  */
  public var diskPath = "moaImageDownloader"
}

func ==(lhs: MoaSettingsCache, rhs: MoaSettingsCache) -> Bool {
  return lhs.memoryCapacityBytes == rhs.memoryCapacityBytes
    && lhs.diskCapacityBytes == rhs.diskCapacityBytes
    && lhs.requestCachePolicy == rhs.requestCachePolicy
    && lhs.diskPath == rhs.diskPath
}

func !=(lhs: MoaSettingsCache, rhs: MoaSettingsCache) -> Bool {
  return !(lhs == rhs)
}


// ----------------------------
//
// MoaSimulatedImageDownloader.swift
//
// ----------------------------

import Foundation

/**

Simulates download of images in unit test. This downloader is used instead of the HTTP downloaded when the moa simulator is started: MoaSimulator.start().

*/
public final class MoaSimulatedImageDownloader: MoaImageDownloader {
  
  /// Url of the downloader.
  public let url: String
  
  /// Indicates if the request was cancelled.
  public var cancelled = false
  
  var autorespondWithImage: MoaImage?
  
  var autorespondWithError: (error: Error?, response: HTTPURLResponse?)?
  
  var onSuccess: ((MoaImage)->())?
  var onError: ((Error, HTTPURLResponse?)->())?

  init(url: String) {
    self.url = url
  }
  
  func startDownload(_ url: String, onSuccess: @escaping  (MoaImage)->(),
    onError: @escaping (Error?, HTTPURLResponse?)->()) {
      
    self.onSuccess = onSuccess
    self.onError = onError
      
    if let autorespondWithImage = autorespondWithImage {
      respondWithImage(autorespondWithImage)
    }
      
    if let autorespondWithError = autorespondWithError {
      respondWithError(autorespondWithError.error, response: autorespondWithError.response)
    }
  }
  
  func cancel() {
    cancelled = true
  }
  
  /**
  
  Simulate a successful server response with the supplied image.
  
  - parameter image: Image that is be passed to success handler of all ongoing requests.
  
  */
  public func respondWithImage(_ image: MoaImage) {
    onSuccess?(image)
  }
  
  /**
  
  Simulate an error response from server.
  
  - parameter error: Optional error that is passed to the error handler ongoing request.
  
  - parameter response: Optional response that is passed to the error handler ongoing request.
  
  */
  public func respondWithError(_ error: Error? = nil, response: HTTPURLResponse? = nil) {
    onError?(error ?? MoaError.simulatedError, response)
  }
}


// ----------------------------
//
// MoaSimulator.swift
//
// ----------------------------

import Foundation

/**

Simulates image download in unit tests instead of sending real network requests.

Example:

    override func tearDown() {
      super.tearDown()

      MoaSimulator.clear()
    }

    func testDownload() {
      // Create simulator to catch downloads of the given image
      let simulator = MoaSimulator.simulate("35px.jpg")

      // Download the image
      let imageView = UIImageView()
      imageView.moa.url = "http://site.com/35px.jpg"

      // Check the image download has been requested
      XCTAssertEqual(1, simulator.downloaders.count)
      XCTAssertEqual("http://site.com/35px.jpg", simulator.downloaders[0].url)

      // Simulate server response with the given image
      let bundle = NSBundle(forClass: self.dynamicType)
      let image =  UIImage(named: "35px.jpg", inBundle: bundle, compatibleWithTraitCollection: nil)!
      simulator.respondWithImage(image)

      // Check the image has arrived
      XCTAssertEqual(35, imageView.image!.size.width)
    }

*/
public final class MoaSimulator {

  /// Array of currently registered simulators.
  static var simulators = [MoaSimulator]()
  
  /**
  
  Returns a simulator that will be used to catch image requests that have matching URLs. This method is usually called at the beginning of the unit test.
  
  - parameter urlPart: Image download request that include the supplied urlPart will be simulated. All other requests will continue to real network.
  
  - returns: Simulator object. It is usually used in unit test to verify which request have been sent and simulating server response by calling its respondWithImage and respondWithError methods.
  
  */
  @discardableResult
  public static func simulate(_ urlPart: String) -> MoaSimulator {
    let simulator = MoaSimulator(urlPart: urlPart)
    simulators.append(simulator)
    return simulator
  }
  
  /**
  
  Respond to all future download requests that have matching URLs. Call `clear` method to stop auto responding.
  
  - parameter urlPart: Image download request that include the supplied urlPart will automatically and immediately succeed with the supplied image. All other requests will continue to real network.
  
  - parameter image: Image that is be passed to success handler of future requests.
  
  - returns: Simulator object. It is usually used in unit test to verify which request have been sent.  One does not need to call its `respondWithImage` method because it will be called automatically for all matching requests.
  
  */
  @discardableResult
  public static func autorespondWithImage(_ urlPart: String, image: MoaImage) -> MoaSimulator {
    let simulator = simulate(urlPart)
    simulator.autorespondWithImage = image
    return simulator
  }
  
  /**
  
  Fail all future download requests that have matching URLs. Call `clear` method to stop auto responding.
  
  - parameter urlPart: Image download request that include the supplied urlPart will automatically and immediately fail. All other requests will continue to real network.
  
  - parameter error: Optional error that is passed to the error handler of failed requests.
  
  - parameter response: Optional response that is passed to the error handler of failed requests.
  
  - returns: Simulator object. It is usually used in unit test to verify which request have been sent.  One does not need to call its `respondWithError` method because it will be called automatically for all matching requests.
  
  */
  @discardableResult
  public static func autorespondWithError(_ urlPart: String, error: Error? = nil,
    response: HTTPURLResponse? = nil) -> MoaSimulator {
      
    let simulator = simulate(urlPart)
    simulator.autorespondWithError = (error, response)
    return simulator
  }
  
  /// Stop using simulators and use real network instead.
  public static func clear() {
    simulators = []
  }
  
  static func simulatorsMatchingUrl(_ url: String) -> [MoaSimulator] {
    return simulators.filter { simulator in
      MoaString.contains(url, substring: simulator.urlPart)
    }
  }
  
  static func createDownloader(_ url: String) -> MoaSimulatedImageDownloader? {
    let matchingSimulators = simulatorsMatchingUrl(url)
    
    if !matchingSimulators.isEmpty {
      let downloader = MoaSimulatedImageDownloader(url: url)

      for simulator in matchingSimulators {
        simulator.downloaders.append(downloader)
        
        if let autorespondWithImage = simulator.autorespondWithImage {
          downloader.autorespondWithImage = autorespondWithImage
        }
        
        if let autorespondWithError = simulator.autorespondWithError {
          downloader.autorespondWithError = autorespondWithError
        }
      }
      
      return downloader
    }
    
    return nil
  }
  
  // MARK: - Instance
  
  var urlPart: String
  
  /// The image that will be used to respond to all future download requests
  var autorespondWithImage: MoaImage?
  
  var autorespondWithError: (error: Error?, response: HTTPURLResponse?)?
  
  /// Array of registered image downloaders.
  public var downloaders = [MoaSimulatedImageDownloader]()
  
  init(urlPart: String) {
    self.urlPart = urlPart
  }
  
  /**
  
  Simulate a successful server response with the supplied image.
  
  - parameter image: Image that is be passed to success handler of all ongoing requests.
  
  */
  public func respondWithImage(_ image: MoaImage) {
    for downloader in downloaders {
      downloader.respondWithImage(image)
    }
  }
  
  /**
  
  Simulate an error response from server.
  
  - parameter error: Optional error that is passed to the error handler of all ongoing requests.
  
  - parameter response: Optional response that is passed to the error handler of all ongoing requests.
  
  */
  public func respondWithError(_ error: Error? = nil, response: HTTPURLResponse? = nil) {
    for downloader in downloaders {
      downloader.respondWithError(error, response: response)
    }
  }
}


// ----------------------------
//
// MoaString.swift
//
// ----------------------------

import Foundation

//
// Helpers for working with strings
//

struct MoaString {
  static func contains(_ text: String, substring: String,
    ignoreCase: Bool = false,
    ignoreDiacritic: Bool = false) -> Bool {
            
    var options = NSString.CompareOptions()
    
    if ignoreCase { _ = options.insert(NSString.CompareOptions.caseInsensitive) }
    if ignoreDiacritic { _ = options.insert(NSString.CompareOptions.diacriticInsensitive) }
    
    return text.range(of: substring, options: options) != nil
  }
}


// ----------------------------
//
// MoaTime.swift
//
// ----------------------------

import Foundation

struct MoaTime {
  /// Converts date to format used in logs in UTC time zone.
  static func logTime(_ date: Date) -> String {
    let dateFormatter = DateFormatter()
    let timeZone = TimeZone(identifier: "UTC")
    dateFormatter.timeZone = timeZone
    let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
    dateFormatter.locale = enUSPosixLocale
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    
    return dateFormatter.string(from: date)
  }
  
  /// Returns current time in format used in logs in UTC time zone.
  static var nowLogTime: String {
    return logTime(Date())
  }
}


