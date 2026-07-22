import GeckoView

RuntimeJITCoordinator.shared.start()
defer { RuntimeJITCoordinator.shared.stop() }
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
