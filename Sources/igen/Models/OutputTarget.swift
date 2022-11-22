struct OutputTarget {
    let originalName: String
    let name: String
    var config: Config
}

typealias AnyDictionary = Dictionary<String, Any>
typealias TargetType = String
typealias Platform = String
typealias Dependency = Dictionary<String, String>
typealias Group = String
typealias BaseSettings = Dictionary<String, String>
typealias Source = String

extension OutputTarget {
    struct Config: Encodable {
        let type: TargetType
        let platform: Platform
        var settings: Settings?
        let sources: [Source]?
        let dependencies: [Dependency]?
        let postCompileScripts: [PostCompileScript]?
    }
}

extension OutputTarget.Config {
    struct PostCompileScript: Encodable {
        let name: String
        let script: String
    }

    struct Settings: Encodable {
        let groups: [Group]?
        var base: BaseSettings?
    }
}
