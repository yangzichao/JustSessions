import Testing

@testable import JustSessions

struct ForwardPortFormTests {
    @Test func thePortOnThisMacIsTheHostsUnlessAnotherIsTyped() {
        var form = ForwardPortForm()
        #expect(!form.canForward)

        form.remotePortText = "3000"
        #expect(form.remotePort == 3000)
        #expect(form.localPort == 3000)
        #expect(form.canForward)

        form.localPortText = " 8080 "
        #expect(form.localPort == 8080)

        form.pick(5173)
        #expect(form.remotePort == 5173)
        #expect(form.localPort == 8080)

        form.localPortText = ""
        #expect(form.localPort == 5173)
    }

    @Test func onlyPortsFrom1To65535Count() {
        for text in ["0", "65536", "-1", "80a", "", " "] {
            #expect(ForwardPortForm.port(in: text) == nil, "\(text)")
        }
        #expect(ForwardPortForm.port(in: "1") == 1)
        #expect(ForwardPortForm.port(in: "65535") == 65535)

        var form = ForwardPortForm(remotePortText: "3000", localPortText: "99999")
        #expect(form.localPort == nil)
        #expect(!form.canForward)
        form.localPortText = "3001"
        #expect(form.canForward)
    }
}
