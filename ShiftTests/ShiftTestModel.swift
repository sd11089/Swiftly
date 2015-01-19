
import Foundation
import CoreData

class ShiftTestModel: Model {

    @NSManaged var postId: String
    @NSManaged var userId: String
    @NSManaged var title: String
    @NSManaged var body: String
    
    override func initalize() {
        super.initalize()
    }
    
    override func extend() {
        super.extend()
        self["url"]  = "http://localhost:3000"
        self["name"] = "posts"
    }
    
    // MARK: Parsing Responses
    
    override func parse(method:Method, _ request: Request) {
        switch method {
        case .GET:
            request.responseSwiftyJSON { (req, response, json, error) -> Void in
                if error == nil {
                    self.set([
                        "postId": json["id"].stringValue,
                        "userId": json["userId"].stringValue,
                        "title":  json["title"].stringValue,
                        "body":   json["body"].stringValue
                    ])
                }
            }
        case .POST:
            request.responseSwiftyJSON({ (req, response, json, error) -> Void in
                if error == nil {
                    self.set([
                        "id": json["id"].stringValue
                    ])
                }
            })
        default:
            request.response({ (request, response:NSHTTPURLResponse?, data, error) -> Void in
                println("\(response?.statusCode)")
                println("\(response)")
            })
        }
    }
    
    override func map(inout map: [String : String]) {
        map["postId"] = "postId"
        map["userId"] = "userId"
        map["title"]  = "title"
        map["body"]   = "body"
    }
    
    // MARK: Authentication
    
    override func authenticate(request: Request) {
        
    }
}
