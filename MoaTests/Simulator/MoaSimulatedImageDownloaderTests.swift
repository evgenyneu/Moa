
import UIKit
import XCTest

class MoaSimulatedImageDownloaderTests: XCTestCase {
  func testInitForUrl_returnNil_urlIsNotSimulated() {
    let result = MoaSimulatedImageDownloader(url: "http://site.com/moa.jpg")
    XCTAssert(result == nil)
  }
  
  func testInitForUrl_urlIsNotSimulated() {
    MoaSimulator.simulate("http://site.com/moa.jpg")
    
    let result = MoaSimulatedImageDownloader(url: "http://site.com/moa.jpg")
    XCTAssert(result == nil)
  }
  
  //  func testCreateForUrl() {
  //    let result = MoaSimulator.createForUrl("http://site.com/image1.jpg")
  //    XCTAssert(result == nil)
  //  }
  
  //  func testStop_removeSimulator() {
  //    MoaSimulator.started = true
  //
  //    MoaSimulator.stop()
  //
  //    XCTAssertFalse(MoaSimulator.started)
  //  }
  
  func testTestSub() {
    //    MoaSimulator.simulateAll()
    //
    //    let moa = Moa()
    //    moa.url = "http://site.com/image1.jpg"
    //    moa.url = "http://site.com/image2.jpg"
    //
    //    XCTAssertEqual(2, MoaSimulator.urls.count)
    //    
    //    MoaSimulator.stop()
    
  }
}