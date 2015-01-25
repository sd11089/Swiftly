
import UIKit
import XCTest
import CoreData

class CollectionTests: XCTestCase {

    private var _collection:SwiftlyTestCollection!
    
    // MARK: Test Setup
    
    override func setUp() {
        super.setUp()
        self.initCoreData()
        self.createCollection()
    }
    
    override func tearDown() {
        super.tearDown()
        self.deinitCoreData()
    }
    
    private func createCollection() {
        _collection = SwiftlyTestCollection(context: _managedObjectContext)
    }
    
    // MARK: Tests 
    
    func testCreate() {
        asyncTest("Test_Create", { (expectation) -> Void in
            self.listenTo(self._collection, event: .Add) { (notification) -> () in
                expectation.fulfill()
            }
            
            var model = self._collection.create()
        }, 5)
    }
    
    func testAdd() {
        asyncTest("Test_Add", { (expectation) -> Void in
            var model = self._collection.instanceModel()
            self.listenTo(self._collection, event: .Add) {(notification) -> () in
                expectation.fulfill()
            }
            self._collection.push([model])
        }, 5)
    }
    
    func testRemove() {
        asyncTest("Test_Remove", { (expectation) -> Void in
            self.listenTo(self._collection, event: .Remove) { (notification) -> () in
                expectation.fulfill()
            }
            
            var model = self._collection.create()
            self._collection.remove([model])
        }, 5)
    }
    
    func testReset() {
        asyncTest("Test_Reset", { (expectation) -> Void in
            var model = self._collection.instanceModel()
            model.set("id", value: "101")
            self._collection.fetch {(request) -> Void in
                XCTAssert(self._collection.length == 100, "Test_Reset_1")
            }
            self.listenTo(self._collection, event: .Reset) {(notification) -> () in
                XCTAssert(self._collection.length == 1, "Test_Reset_2")
                expectation.fulfill()
            }
            self._collection.reset(models: [model], options: nil)
        }, 5)
    }
    
    func testSet() {
        asyncTest("Test_Set", { (expectation) -> Void in
            var model = self._collection.instanceModel()
            model.set("id", value: "101")
            self._collection.fetch { (request) -> Void in
                XCTAssert(self._collection.length == 100, "Test_Set_1")
                self._collection.set([model])
                XCTAssert(self._collection.length == 1, "Test_Set_2")
                expectation.fulfill()
            }
        }, 5)
    }
    
    func testUnshift() {
        asyncTest("Test_Unshift", {(expectation) -> Void in
            var model = self._collection.instanceModel()
            model.set("id", value: "101")
            self.listenTo(self._collection, event: .Add) {(notification) -> () in
                XCTAssert(self._collection.length == 101, "Test_Unshift_2")
                XCTAssert(self._collection.at(0) == model, "Test_Unshift_3")
                expectation.fulfill()
            }
            
            self._collection.fetch {(request) -> Void in
                XCTAssert(self._collection.length == 100, "Test_Unshift_1")
                self._collection.unshift(model)
            }
        }, 5)
    }
    
    func testShift() {
        asyncTest("Test_Shift", {(expectation) -> Void in
            self.listenTo(self._collection, event: .Remove, callback: {(notification) -> () in
                XCTAssert(self._collection.length == 99, "Test_Shift_3")
                expectation.fulfill()
            })
            
            self._collection.fetch({(request) -> Void in
                XCTAssert(self._collection.length == 100, "Test_Shift_1")
                var model = self._collection.at(0)
                XCTAssert(self._collection.shift() == model, "Test_Shift_2")
            })
            
        }, 5)
    }
    
    func testSlice() {
        asyncTest("Test_Slice", {(expectation) -> Void in
            var model1:Model?, model2:Model?
            self.listenTo(self._collection, event: .Remove, callback: {(notification) -> () in
                XCTAssert(self._collection.length == 98, "Test_Slice_2")
                if let models = notification.userInfo?["models"] as? [Model] {
                    XCTAssert(models.inArray(model1!) && models.inArray(model2!), "Test_Slice_3")
                }
                expectation.fulfill()
            })
            
            self._collection.fetch({(request) -> Void in
                XCTAssert(self._collection.length == 100, "Test_Slice_1")
                model1 = self._collection.at(0)
                model2 = self._collection.at(1)
                var models = self._collection.slice(0, length: 2)
            })
            
        }, 5)
    }
    
    func testSplice() {
        asyncTest("Test_Splice", {(expectation) -> Void in
            self._collection.fetch({(request) -> Void in
                var model = $.chain(self._collection.instanceModel(), function: {(model:Model) -> Any? in
                    model.set("id", value: "101")
                })
                
                self.listenTo(self._collection, event: .Remove, callback: {(notification) -> () in
                    XCTAssert(self._collection.length == 98, "Test_Splice_2")
                })
                self.listenTo(self._collection, event: .Add, callback: {(notification) -> () in
                    XCTAssert(self._collection.length == 99, "Test_Splice_2")
                    XCTAssert(self._collection.at(3) == model, "Test_Splice_3")
                    expectation.fulfill()
                })
                var removedModels = self._collection.splice([model], start: 3, length: 2)
            })
        }, 5)
    }
    
    func testWebServiceGET() {
        asyncTest("Test_Fetch", { (expectation) -> Void in
            var expectation = self.expectationWithDescription("Test_Fetch")
            self._collection.fetch { (request) -> Void in
                XCTAssert(self._collection.length == 100, "Test_Fetch_1")
                expectation.fulfill()
            }
        }, 5)
    }
    
    func testUpdatedModels() {
        asyncTest("Test_Update", { (expectation) -> Void in
            var model = self._collection.create(properties: ["id": "1"], options: [Options.Fetch])
            
            // Updated models = 99 (1 already existed and didn't change on fetch)
            self._collection.fetch { (request) -> Void in
                XCTAssert(self._collection.updatedModels.length == 99, "Test_Update_1")
                
                
                // Updated models = 0 (All models already existed, and didn't change)
                self._collection.fetch { (request) -> Void in
                    XCTAssert(self._collection.updatedModels.length == 0, "Test_Update_2")
                    
                    // Update an individual model
                    model.set("newProp", value: "newValue")
                    XCTAssert(self._collection.updatedModels.length == 1, "Test_Update_3")
                    expectation.fulfill()
                }
            }
        }, 5)
    }
    
    func testComparator() {
        asyncTest("Test_Comparator", { (expectation) -> Void in
            self._collection.comparator = { (modelA, modelB) -> Int in
                var idA = modelA.get("title") as String
                var idB = modelB.get("title") as String
                return idA > idB ? 1 : -1
            }
            
            self._collection.fetch { (request) -> Void in
                self._collection.sort()
                var modelA = self._collection.first().first
                var modelB = self._collection.last().first
                expectation.fulfill()
            }
        }, 5)
    }
    
    func testTrigger() {
        asyncTest("Test_Trigger", { (expectation) -> Void in
            var expectation = self.expectationWithDescription("Test_Trigger")
            self.listenTo(self._collection, event: .Change) {(notification) -> () in
                expectation.fulfill()
            }
            self._collection.trigger(.Change, info: nil)
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
        self.clearContext()
        
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
        if NSFileManager.defaultManager().fileExistsAtPath(self.applicationDocumentsDirectory.path!) {
            NSFileManager.defaultManager().removeItemAtPath(self.applicationDocumentsDirectory.path!, error: nil)
        }
    }

    
}
