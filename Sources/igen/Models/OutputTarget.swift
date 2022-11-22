struct OutputTarget {
    let originalName: String
    let name: String
    var config: Config
}

extension OutputTarget {
    struct Config: Encodable {
        let type: String
        let platform: String
        var settings: Settings?
        let sources: [String]?
        let dependencies: [Dictionary<String, String>]?
        let postCompileScripts: [PostCompileScript]?
    }
}

extension OutputTarget.Config {
    struct PostCompileScript: Encodable {
        let name: String
        let script: String
    }

    struct Settings: Encodable {
        let groups: [String]?
        var base: Dictionary<String, String>?
    }
}
