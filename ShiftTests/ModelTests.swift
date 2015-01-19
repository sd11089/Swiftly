
import UIKit
import XCTest
import CoreData

class ModelTests: XCTestCase {
    
    private var _model:ShiftTestModel!
    
    // MARK: Test Setup
    
    override func setUp() {
        super.setUp()
        self.initCoreData()
        self.createModel()
    }
    
    override func tearDown() {
        super.tearDown()
        self.deinitCoreData()
    }
    
    private func createModel() {
        _model = NSEntityDescription.insertNewObjectForEntityForName("ShiftTestModel", inManagedObjectContext: _managedObjectContext) as ShiftTestModel
    }
    
    // MARK: Tests
    
    func testModelGetAndSet() {
        _model.clear()
        _model.set("foo", value: "bar")
        _model.set(["foo2":"bar2"], options: nil)
        XCTAssert(_model.get("foo") as? String == "bar", "Set property directly")
        XCTAssert(_model.get("foo2") as? String == "bar2", "Set property with array")
    }
    
    func testModelEscape() {
        _model.clear()
        _model.set("escaped", value: "Test Escape")
        XCTAssert(_model.escape("escaped") == "Test%20Escape", "Escaping worked")
    }
    
    func testPropertyUpdates() {
        _model.clear()
        _model.set("foo", value: "bar")
        _model.unset("foo")
        XCTAssert(_model.has("xfoo") == false, "Properly unsets property and check that it no longer exists")
    }
    
    func testToJSON() {
        _model.clear()
        _model.set("foo", value: "bar")
        println("\(_model.toJSON())")
    }
    
    func testExtension() {
        XCTAssert(_model.get("name") as? String == "posts", "Subclass name correct")
        XCTAssert(_model.get("url") as? String == "http://localhost:3000", "Extension overrode URL")
    }
    
    func testWebServiceGET() {
        var expectation = expectationWithDescription("GET")
        _model.set("id", value: "1")
        self.listenTo(_model, event: .Change) { (notification) -> () in
            XCTAssert(true);
            expectation.fulfill()
        }
        
        // Execute GET request
        _model.fetch()
        
        self.waitForExpectationsWithTimeout(3, handler: { (error) -> Void in
            println("\(self._model.toJSON())")
        })
    }
    
    func testWebServicePOST() {
        var expectation = expectationWithDescription("POST")
        
        _model.set("id", value: "")
        self.listenTo(_model, event: .Save) {(notification) -> () in
            var error = notification.userInfo?["error"] as? NSError
            println(error == nil)
            println(self._model.get("id") as? String)
            XCTAssert(self._model.get("id") as? String == "101")
            expectation.fulfill()
        }
        
        // Execute POST request
        _model.save()
        
        self.waitForExpectationsWithTimeout(3, handler: {(error) -> Void in })
    }
    
    func testWebServicePOSTOptions() {
        var expectation = expectationWithDescription("POST_OPTIONS")
        
        // Execute POST request
        _model.set("id", value: "")
        XCTAssert(self._model.changedProperties.count == self._model.properties.count, "No properties saved to server")
        _model.save() {(req:Request) in
            self._model["id"] = "2"
            XCTAssert(self._model.changedProperties.count == 1, "One property changed")
            
            self._model.save(options: [.Difference]) {(req2:Request) in
                XCTAssert(self._model.changedProperties.count == 0, "No more properties have been changed")
                expectation.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(3, handler: {(error) -> Void in })
    }
    
    func testWebServiceDELETE() {
        var expectation = expectationWithDescription("DELETE")
        _model.set("id", value: "1")
        self.listenTo(_model, event: .Delete) { (notification) -> () in
            var error = notification.userInfo?["error"] as? NSError
            println(error == nil)
            XCTAssert(true)
        }
        
        // Execute DELETE request
        _model.destroy() {(req:Request) in
            req.response({ (request, response, data, error) -> Void in
                println("Callback")
                println("\(response)")
                expectation.fulfill()
            })
            return
        }
        
        self.waitForExpectationsWithTimeout(3, handler: {(error) -> Void in })
    }
    
    func testHasChanges() {
        var expectation = expectationWithDescription("HAS_CHANGES")
        _model.set("TEST", value: "VALUE")
        XCTAssert(_model.hasChanges == true, "Model has changes")
        
        _model.save(nil, nil) { (request) in
            expectation.fulfill()
            XCTAssert(self._model.hasChanges == false, "Model no longer has changes")
        }
        
        self.waitForExpectationsWithTimeout(3, handler: {(error) -> Void in })
    }
    
    func testPriorProperties() {
        var expectation = expectationWithDescription("HAS_CHANGES")
        
        // Set initial value
        _model.set("id", value: "1")
        XCTAssert(_model.get("id") as? String == "1", "Model has changes")
        
        // Save initial value
        _model.save() { (request) in
            XCTAssert(self._model.hasChanges == false, "Model no longer has changes")
            
            // Set new value and check prior
            self._model.set("id", value: "2")
            XCTAssert(self._model.prior("id") as? String == "1", "Prior ID is 1")
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(3, handler: {(error) -> Void in })
    }
    
    // MARK: Core Data 
    
    private var _managedObjectContext:NSManagedObjectContext!
    private var _managedObjectModel:NSManagedObjectModel!
    private var _storeCoordinator:NSPersistentStoreCoordinator!
    private var applicationDocumentsDirectory:NSURL {
        var documentsDirectory:NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first! as NSString
        return NSURL(fileURLWithPath: documentsDirectory.stringByAppendingString("ShiftTests.data"))!
    }
    
    private func initCoreData() {
        var bundle = NSBundle(forClass: self.dynamicType)
        if let modelUrl = bundle.URLForResource("ShiftTests", withExtension: "momd") {
            _managedObjectModel   = NSManagedObjectModel(contentsOfURL: modelUrl)
            _storeCoordinator     = NSPersistentStoreCoordinator(managedObjectModel: _managedObjectModel)
            
            var error:NSError?
            if _storeCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.applicationDocumentsDirectory, options: nil, error: &error) == nil {
                NSException(name: "Failed to create SQLLite test stored", reason: "Reason: \(error?.localizedDescription)", userInfo: nil).raise()
            }
            
            _managedObjectContext = NSManagedObjectContext()
            _managedObjectContext.persistentStoreCoordinator = _storeCoordinator
            _managedObjectContext.undoManager = nil
        }
    }
    
    private func deinitCoreData() {
        self.clearContext()
    }
    
    private func saveContext() -> Bool {
        var error:NSError?
        let success = _managedObjectContext.save(&error)
        if !success {
            Debug.log(.Error, message: "ShiftTests.saveContext(): \(error?.localizedDescription)")
        }
        return success
    }
    
    private func clearContext() {
        NSFileManager.defaultManager().removeItemAtPath(self.applicationDocumentsDirectory.path!, error: nil)
    }
}
