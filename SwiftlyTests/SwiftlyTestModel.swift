
import Foundation
import CoreData

class SwiftlyTestModel: Model {

    @NSManaged var postId: String
    @NSManaged var userId: String
    @NSManaged var title: String
    @NSManaged var body: String
    
    override func initalize() {
        super.initalize()
    }
    
    override func extend() {
        super.extend()
        self["url"]  = "http://jsonplaceholder.typicode.com"
        self["name"] = "posts"
    }
    
    // MARK: Parsing Responses
    
    override func map(inout map: [String : String]) {
        map["postId"] = "postId"
        map["userId"] = "userId"
        map["title"]  = "title"
        map["body"]   = "body"
    }

    override func parse(request: NSURLRequest, response: NSHTTPURLResponse?, json: JSON?, error: NSError?) -> Hash? {
        if json != nil && error == nil {
            switch request.HTTPMethod! {
            case "GET":
                return [
                    "id":     json!["id"].stringValue,
                    "postId": json!["id"].stringValue,
                    "userId": json!["userId"].stringValue,
                    "title":  json!["title"].stringValue,
                    "body":   json!["body"].stringValue
                ]
            case "POST":
                return [
                    "id": json!["id"].stringValue,
                ]
            default:
                println("Unhandled Request Type: \(request.HTTPMethod!)")
            }
        }
        return nil
    }
    
    override func saveMassage(property: String, inout value: AnyObject?) {}
    
    // MARK: Authentication
    
    override func authenticate(request: Request) {}
}
