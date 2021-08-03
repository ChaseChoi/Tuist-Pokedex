import ProjectDescription

let reverseOrganizationName = "com.sonomos"

/// Project helpers are functions that simplify the way you define your project.
/// Share code to create targets, settings, dependencies,
/// Create your own conventions, e.g: a func that makes sure all shared targets are "static frameworks"
/// See https://tuist.io/docs/usage/helpers/

public struct LocalFramework {
    let name: String
    let path: String
    let frameworkDependancies: [TargetDependency]
    let resources: [String]
    
    public init(name: String, path: String, frameworkDependancies: [TargetDependency], resources: [String]) {
        self.name = name
        self.path = path
        self.frameworkDependancies = frameworkDependancies
        self.resources = resources
    }
}

extension Project {
    /// Helper function to create the Project for this ExampleApp
    public static func app(name: String,
                           platform: Platform,
                           packages: [Package],
                           targetDependancies: [TargetDependency],
                           additionalTargets: [LocalFramework]) -> Project {
        
        let organizationName = "Sonomos.com"
        var dependencies = additionalTargets.map { TargetDependency.target(name: $0.name) }
        dependencies.append(contentsOf: targetDependancies)
        
        var targets = makeAppTargets(name: name,
                                     platform: platform,
                                     dependencies: dependencies)
        targets += additionalTargets.flatMap({ makeFrameworkTargets(localFramework: $0, platform: platform) })
        
        let schemes = makeSchemes(targetName: name)
        
        return Project(name: name,
                       organizationName: organizationName,
                       packages: packages,
                       targets: targets,
                       schemes: schemes)
    }

    // MARK: - Private

    /// Helper function to create a framework target and an associated unit test target
    private static func makeFrameworkTargets(localFramework: LocalFramework, platform: Platform) -> [Target] {
        let relativeFrameworkPath = "../\(localFramework.path)/Targets/\(localFramework.name)"
        let resources = localFramework.resources
        let resourceFilePaths = resources.map { ResourceFileElement.glob(pattern: Path("../\(localFramework.path)/" + $0), tags: [])}
        let sources = Target(name: localFramework.name,
                platform: platform,
                product: .framework,
                bundleId: "\(reverseOrganizationName).\(localFramework.name)",
                infoPlist: .default,
                sources: ["\(relativeFrameworkPath)/Sources/**"],
                resources: ResourceFileElements(resources: resourceFilePaths),
                headers: Headers(public: ["\(relativeFrameworkPath)/Sources/**/*.h"]),
                dependencies: localFramework.frameworkDependancies)
        
        let tests = Target(name: "\(localFramework.name)Tests",
                platform: platform,
                product: .unitTests,
                bundleId: "\(reverseOrganizationName).\(localFramework.name)Tests",
                infoPlist: .default,
                sources: ["\(relativeFrameworkPath)/Tests/**"],
                resources: [],
                dependencies: [.target(name: localFramework.name)])
        
        return [sources, tests]
    }

    /// Helper function to create the application target and the unit test target.
    private static func makeAppTargets(name: String, platform: Platform, dependencies: [TargetDependency]) -> [Target] {
        let platform: Platform = platform
        let infoPlist: [String: InfoPlist.Value] = [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "UIMainStoryboardFile": "",
            "UILaunchStoryboardName": "LaunchScreen"
            ]

        let mainTarget = Target(
            name: name,
            platform: platform,
            product: .app,
            bundleId: "\(reverseOrganizationName).\(name)",
            infoPlist: .extendingDefault(with: infoPlist),
            sources: ["Targets/\(name)/Sources/**"],
            resources: ["Targets/\(name)/Resources/**"
            ],
            actions: [
                TargetAction.post(path: "../scripts/swiftlint.sh", arguments: ["$TARGETNAME"], name: "SwiftLint")
            ],
            dependencies: dependencies
        )

        let testTarget = Target(
            name: "\(name)Tests",
            platform: platform,
            product: .unitTests,
            bundleId: "\(reverseOrganizationName).\(name)Tests",
            infoPlist: .default,
            sources: ["Targets/\(name)/Tests/**"],
            resources: [],
            dependencies: [
                .target(name: "\(name)")
        ])
        
        let uiTestTarget = Target(
            name: "\(name)-UITests",
            platform: platform,
            product: .uiTests,
            bundleId: "\(reverseOrganizationName).\(name)-UITests",
            infoPlist: .default,
            sources: ["Targets/\(name)/UITests/**"],
            resources: [],
            dependencies: [
                .target(name: "\(name)")
        ])
        
        return [mainTarget, testTarget, uiTestTarget]
    }

    public static func makeSchemes(targetName: String) -> [Scheme] {
        let mainTargetReference = TargetReference(stringLiteral: targetName)
        let debugConfiguration = "Debug"
        let coverage = true
        let codeCoverageTargets: [TargetReference] = [mainTargetReference]
        let buildAction = BuildAction(targets: [mainTargetReference])
        let executable = mainTargetReference
        let networkTestingLaunchArguments = Arguments(launchArguments: [LaunchArgument(name: "Network", isEnabled: true)])
        let uiTestingLaunchArguments = Arguments(launchArguments: [LaunchArgument(name: "UITesting", isEnabled: true)])
        
        let testAction = TestAction(targets: [TestableTarget(stringLiteral: "\(targetName)UITests")],
                                    configurationName: debugConfiguration,
                                    coverage: coverage,
                                    codeCoverageTargets: codeCoverageTargets)

        let networkTestingScheme = Scheme(
            name: "\(targetName) Network Testing",
            shared: false,
            buildAction: buildAction,
            runAction: RunAction(configurationName: debugConfiguration,
                                 executable: executable,
                                 arguments: networkTestingLaunchArguments)
        )
        
        let uiTestingScheme = Scheme(
            name: "\(targetName) UITesting",
            shared: false,
            buildAction: buildAction,
            testAction: testAction,
            runAction: RunAction(configurationName: debugConfiguration,
                                 executable: executable,
                                 arguments: uiTestingLaunchArguments)
        )
        
        return [networkTestingScheme, uiTestingScheme]
    }
}