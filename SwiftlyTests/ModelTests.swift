
import UIKit
import XCTest
import CoreData

class ModelTests: XCTestCase {
    
    private var _model:SwiftlyTestModel!
    
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
        _model = NSEntityDescription.insertNewObjectForEntityForName("SwiftlyTestModel", inManagedObjectContext: _managedObjectContext) as SwiftlyTestModel
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
    }
    
    func testWebServiceGET() {
        asyncTest("Test_Get", { (expectation) -> Void in
            self._model.set("id", value: "1")
            self.listenTo(self._model, event: .Change) { (notification) -> () in
                XCTAssert(true);
                expectation.fulfill()
            }
            
            // Execute GET request
            self._model.fetch({(request) -> Void in
                println("\(self._model.toJSON())")
            })
        }, 5)
    }
    
    func testWebServicePOST() {
        asyncTest("Test_Post", { (expectation) -> Void in
            self._model.set("id", value: "")
            self.listenTo(self._model, event: .Save) {(notification) -> () in
                var error = notification.userInfo?["error"] as? NSError
                println(error == nil)
                println(self._model.get("id") as? String)
                XCTAssert(self._model.get("id") as? String == "101")
                expectation.fulfill()
            }
            
            // Execute POST request
            self._model.save()
        }, 5)
    }
    
    func testWebServicePOSTOptions() {
        asyncTest("Test_Post_Options", { (expectation) -> Void in
            self._model.set("id", value: "")
            XCTAssert(self._model.changedProperties.count == self._model.properties.count, "No properties saved to server")
            self._model.save() {(req:Request) in
                self._model["id"] = "2"
                XCTAssert(self._model.changedProperties.count == 1, "One property changed")
                
                self._model.save(options: [.Difference]) {(req2:Request) in
                    XCTAssert(self._model.changedProperties.count == 0, "No more properties have been changed")
                    expectation.fulfill()
                }
            }
        }, 5)
    }
    
    func testWebServiceDELETE() {
        asyncTest("Test_Delete", { (expectation) -> Void in
            self._model.set("id", value: "1")
            self.listenTo(self._model, event: .Delete) { (notification) -> () in
                var error = notification.userInfo?["error"] as? NSError
                println(error == nil)
                XCTAssert(true)
            }
            
            // Execute DELETE request
            self._model.destroy() {(req:Request) in
                req.response({ (request, response, data, error) -> Void in
                    println("Callback")
                    println("\(response)")
                    expectation.fulfill()
                })
                return
            }
        }, 5)
    }
    
    func testHasChanges() {
        asyncTest("Test_HasChanges", { (expectation) -> Void in
            self._model.set("TEST", value: "VALUE")
            XCTAssert(self._model.hasChanges == true, "Model has changes")
            
            self._model.save(nil, nil) { (request) in
                expectation.fulfill()
                XCTAssert(self._model.hasChanges == false, "Model no longer has changes")
            }
        }, 5)
    }
    
    func testPriorProperties() {
        asyncTest("Test_PriorProperties", { (expectation) -> Void in
            // Set initial value
            self._model.set("id", value: "1")
            XCTAssert(self._model.get("id") as? String == "1", "Model has changes")
            
            // Save initial value
            self._model.save() { (request) in
                XCTAssert(self._model.hasChanges == false, "Model no longer has changes")
                
                // Set new value and check prior
                self._model.set("id", value: "2")
                XCTAssert(self._model.prior("id") as? String == "1", "Prior ID is 1")
                expectation.fulfill()
            }
        }, 5)
    }

    
    // MARK: Core Data 
    
    private var _managedObjectContext:NSManagedObjectContext!
    private var _managedObjectModel:NSManagedObjectModel!
    private var _storeCoordinator:NSPersistentStoreCoordinator!
    private var applicationDocumentsDirectory:NSURL {
        var documentsDirectory:NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first! as NSString
        return NSURL(fileURLWithPath: documentsDirectory.stringByAppendingString("/SwiftlyTests.data"))!
    }
    
    private func initCoreData() {
        var bundle = NSBundle(forClass: self.dynamicType)
        if let modelUrl = bundle.URLForResource("SwiftlyTests", withExtension: "momd") {
            _managedObjectModel   = NSManagedObjectModel(contentsOfURL: modelUrl)
            _storeCoordinator     = NSPersistentStoreCoordinator(managedObjectModel: _managedObjectModel)
            
            var error:NSError?
            
            var options:Hash = ["journal_mode": "MEMORY", NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
            if _storeCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.applicationDocumentsDirectory, options: options, error: &error) == nil {
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
            debug.log(.Error, message: "SwiftlyTests.saveContext(): \(error?.localizedDescription)")
        }
        return success
    }
    
    private func clearContext() {
        NSFileManager.defaultManager().removeItemAtPath(self.applicationDocumentsDirectory.path!, error: nil)
    }
}
