extension String {
    var rootDirectoryPath: String {
        Array(self.components.dropLast()).asPath
    }

    var lastDirectory: String? {
        if let last = components.last, last.isDirectory {
            return self
        }
        let pathComponents = Array(components.dropLast())
        if let last = components.last, last.isDirectory {
            return pathComponents.asPath
        }
        return nil
    }

    var isDirectory: Bool {
        guard let lastComponent = components.last else { return false}
        return !lastComponent.contains(".")
    }

    func prefixed(with prefix: String?) -> String {
        "\(prefix ?? "")\(self)"
    }

    var components: [String] {
        self.split(separator: "/").map(String.init)
    }
}
