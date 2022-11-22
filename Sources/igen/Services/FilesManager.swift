import Foundation

struct FilesManager {
    func updateProjectYAML(path: String, lines: [String]) throws {
        let url = URL(fileURLWithPath: path)
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    func updateTargetsYAML(path: String, config: InputConfig, lines: [String]) throws {
        let newConfig = InputConfig(
            projectName: config.projectName,
            targets: config.targets.map { .init(name: $0.name, steals: nil, inherit: nil) }
        )

        guard let targetsIndex = lines.firstIndex(where: { $0 == "targets:" }) else {
            print("No field named `targets` found!")
            throw Error.noTargetFieldFound
        }

        let targetsLines = newConfig.targets
            .sorted { $0.name < $1.name }
            .map { "    \($0.name):"}

        var newLines = lines
        newLines.removeSubrange((targetsIndex + 1)...)
        newLines.insert(contentsOf: targetsLines, at: (targetsIndex + 1))

        let url = URL(fileURLWithPath: path)
        try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
