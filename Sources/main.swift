import Alamofire
import SwiftyJSON
import Vapor
import RealmSwift

struct Joke: Decodable {
    let setup: String
    let punchline: String
}

print("Starting the Swift project with a joke...")

// Fetch a random joke using Alamofire
AF.request("https://official-joke-api.appspot.com/jokes/random").responseDecodable(of: Joke.self) { response in
    switch response.result {
    case .success(let joke):
        print("\(joke.setup) - \(joke.punchline)")
    case .failure(let error):
        print("Error fetching joke: \(error.localizedDescription)")
    }
}

// Set up a Realm instance
class User: Object {
    @objc dynamic var id: String = UUID().uuidString
    @objc dynamic var name: String = ""
    @objc dynamic var email: String = ""
    override static func primaryKey() -> String? {
        return "id"
    }
}

let realm = try! Realm()
try! realm.write {
    let user = User()
    user.name = "John Doe"
    user.email = "john@example.com"
    realm.add(user)
}

print("Stored user in Realm: \(realm.objects(User.self).first?.name ?? "Unknown")")

// Vapor HTTP server setup example
let app = Application(.testing)
defer { app.shutdown() }

app.get("hello") { req -> String in
    return "Hello, world!"
}

try! app.start()
