import PackagePlugin

@main struct SwiftEntitlementsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        if let binaryTarget = target as? BinaryArtifactTarget {
            return try [createCodesignCommand(context: context, target: binaryTarget)]
        } else {
            return []
        }
    }

    func createCodesignCommand(context: PluginContext, target: BinaryArtifactTarget) throws -> Command {
        let entitlementsPath = target.directory.appending("\(target.name).entitlements")
        return try .buildCommand(
                displayName: "Running codesign",
                executable: context.tool(named: "codesign").path,
                arguments: [
                    "--sign", "-", "--entitlements", entitlementsPath.string, "--force", target.artifact.string
                ],
                inputFiles: [target.artifact, entitlementsPath],
                outputFiles: [target.artifact])
    }
}