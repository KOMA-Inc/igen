import Yams

struct InputConfig {
    let projectName: String
    let targets: [Target]
}

struct Target {
    let name: String
    let steals: [String]?
    let inherit: String?
}

struct ProjectTarget {

    struct Config: Encodable {

        struct Settings: Encodable {
            let groups: [String]
            var base: Dictionary<String, String>
        }

        let type: String
        let platform: String
        var settings: Settings
        let sources: [String]
    }

    let originalName: String
    let name: String
    var config: Config
}


