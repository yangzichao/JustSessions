import Darwin

/// The machine the tests run on.
enum TestMachine {
    /// Running in a virtual machine, such as the release workflow's GitHub runner. There, Ghostty's terminal drew its
    /// background in the configured color but its text and cell colors in others, so checks of those exact colors run
    /// only on a Mac's own hardware, as `make verify` does before every release.
    static let isVirtual: Bool = {
        var isVirtual: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("kern.hv_vmm_present", &isVirtual, &size, nil, 0) == 0 && isVirtual == 1
    }()
}
