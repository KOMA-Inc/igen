struct SourcesManager {
    private let shell = Shell()

    func createSourceDirs(for targets: [OutputTarget]) {
        targets.forEach { target in
            target.config.sources?.forEach { source in
                if let directory = source.lastDirectory {
                    // createRecursiveDirectory(directory)
                    print(shell.mkdir(directory))
                }
            }
        }
    }

    func stealFiles(inputConfig: InputConfig, outputTargets: [OutputTarget]) {
        let targets = newTargets(inputConfig: inputConfig, outputTargets: outputTargets)
        targets.forEach { target in
            guard let steals = target.steals else {
                print("Target \(target.name) has nothing to steal")
                return
            }

            steals.forEach { steal in
                let fullSteal = "/\(steal)".prefixed(with: inputConfig.projectName)
                let output = shell.ls(fullSteal)
                let filesToSteal = output.split(separator: "\n").map(String.init)

                guard !filesToSteal.isEmpty else { return }

                let firstFilePath = filesToSteal.first!

                let isDirectory = shell.isDirecory(firstFilePath)

                let rootDirectory = firstFilePath == "/\(steal)".prefixed(with: inputConfig.projectName) && isDirectory
                ? firstFilePath
                : firstFilePath.rootDirectoryPath

                stealFiles(from: filesToSteal, for: target, using: rootDirectory)
            }
        }
    }

    private func newTargets(inputConfig: InputConfig, outputTargets: [OutputTarget]) -> [InputTarget] {
        inputConfig.targets.filter { inputTarget in
            outputTargets.contains {
                $0.name == inputTarget.name.prefixed(with: inputConfig.projectName)
            }
        }
    }

    private func stealFiles(from paths: [String], for target: InputTarget, using rootDirectory: String) {
        var pathComponents = rootDirectory.components
        pathComponents[1] = target.name
        let newDirectoryFilePath = pathComponents.asPath

        shell.mkdir(newDirectoryFilePath)

        paths.forEach {
            if shell.isDirecory($0) {
                shell.cp(recursive: true, $0, newDirectoryFilePath)
            } else {
                shell.cp(recursive: false, $0, newDirectoryFilePath)
            }
        }
    }
}
