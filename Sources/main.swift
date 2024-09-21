import Foundation

struct Joke: Decodable {
    let setup: String
    let punchline: String
}

print("Starting request to fetch a random joke...")

let url = URL(string: "https://official-joke-api.appspot.com/jokes/random")!
let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: url) { data, _, error in
    if let error = error {
        print("Error: \(error.localizedDescription)")
    } else if let data = data {
        if let joke = try? JSONDecoder().decode(Joke.self, from: data) {
            print("\(joke.setup) - \(joke.punchline)")
        } else {
            print("Error decoding JSON")
        }
    }
    semaphore.signal()
}

task.resume()
semaphore.wait()

print("Request completed")
