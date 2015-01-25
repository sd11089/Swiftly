
import UIKit
import XCTest

extension XCTestCase {
    func asyncTest(name:String, _ test:(expectation:XCTestExpectation) -> Void, _ timeout: NSTimeInterval) {
        test(expectation: self.expectationWithDescription(name))
        self.waitForExpectationsWithTimeout(NSTimeInterval(timeout), handler: { (error) -> Void in })
    }
}

class SwiftlyTests: XCTestCase {
   
    // MARK: Test Setup and Teardown
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    // MARK: Tests
    
    func testMap()  {
        var values = $.map([1, 2, 3], iteratee: { (elem, array) -> Int in
            return elem * 3
        })
        XCTAssert(values == [3, 6, 9], "Test_Map")
    }
    
    func testFind() {
        var value = $.find([1, 2, 3, 4, 5, 6, 7], predicate: { (elem, index, array) -> Bool in
            return elem % 2 == 0
        })
        XCTAssert(value == 2, "Test_Find")
    }
    
    func testFilter() {
        var values = $.filter([1, 2, 3, 4, 5, 6, 7], predicate: { (elem, index, array) -> Bool in
            return elem % 2 == 0
        })
        XCTAssert(values == [2, 4, 6], "Test_Filter")
    }
    
    func testReject() {
        var values = $.reject([1, 2, 3, 4, 5, 6, 7], predicate: { (elem) -> Bool in
            return elem % 2 == 0
        })
        XCTAssert(values == [1, 3, 5, 7], "Test_Reject")
    }
    
    func testEvery() {
        var every = $.every([true, "1", false], predicate: { (elem, array) -> Bool in
            return elem == true
        })
        XCTAssert(every == false, "Test_Every")
    }
    
    func testSome() {
        var some = $.some([true, "1", false], predicate: { (elem, array) -> Bool in
            return elem == true
        })
        XCTAssert(some == true, "Test_Some")
    }
    
    func testInvoke() {
        var array = [1, 2, 3]
        $.invoke(&array, iteratee: { $0 * 10 })
        XCTAssert(array == [10, 20, 30], "Test_Invoke")
    }
    
    func testSort() {
        var array  = ["A", "C", "B", "C", "B"]
        var sorted = $.sort(array, comparator: { (elemA, elemB) -> Int in
            return (elemA > elemB) ? 1 : -1
        })
        XCTAssert(sorted == ["A", "B", "B", "C", "C"], "Test_Sort")
    }
    
    func testPluck() {
        var objects = [["name": "Apple"], ["name":"Cat"], ["name": "Brown"]]
        var names   = $.pluck(objects, key: "name")
        XCTAssert(names == ["Apple", "Cat", "Brown"], "Test_Pluck")
    }
    
    func testGroup() {
        var groups = $.group([1.3, 2.1, 2.4], iteratee: { Int($0) })
        XCTAssert(groups[2]?.length == 2, "Test_Group")
    }
    
    func testShuffle() {
        var shuffled = $.shuffle([1, 2, 3, 4])
        XCTAssert(shuffled != [1, 2, 3, 4], "Test_Shuffle")
    }
    
    func testLast() {
        var last = $.last([1, 2, 3, 4, 5], length: 2)
        XCTAssert(last == [4, 5], "Test_Last")
    }
    
    func testChaining() {
        var value   = 5
        var chained = value ~> increment ~> square
        XCTAssert(chained == 36, "Test_Chaining")
    }
    
    // MARK: Helper Functions
    
    func increment(x: Int) -> Int {
        return x + 1
    }
    
    func square(x: Int) -> Int {
        return x * x
    }
}
