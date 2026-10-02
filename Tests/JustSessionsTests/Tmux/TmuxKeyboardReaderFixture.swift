/// A raw-input CLI stand-in. Terminal initialization can deliver device-attribute replies before user keys;
/// recognize those replies as a real terminal program does, while recording every other byte unchanged.
enum TmuxKeyboardReaderFixture {
    static let script = #"""
        #!/usr/bin/python3
        import os
        import pathlib
        import time
        import tty

        tty.setraw(0)
        key_log = pathlib.Path(os.environ["KEY_LOG"])
        key_log.write_bytes(b"")
        pathlib.Path(os.environ["READY_MARKER"]).write_text("")
        os.write(1, b"KEY_READER_READY")

        recorded = bytearray()
        while len(recorded) < 8:
            first = os.read(0, 1)
            if not first:
                raise SystemExit("terminal closed before the keys arrived")
            sequence = bytearray(first)
            if first == b"\x1b":
                sequence.extend(os.read(0, 1))
                if sequence == b"\x1b[":
                    while True:
                        next_byte = os.read(0, 1)
                        if not next_byte:
                            raise SystemExit("incomplete terminal sequence")
                        sequence.extend(next_byte)
                        if 0x40 <= next_byte[0] <= 0x7e:
                            break
                    if sequence.startswith((b"\x1b[?", b"\x1b[>")) and sequence.endswith(b"c"):
                        continue
            recorded.extend(sequence)
            key_log.write_bytes(recorded)

        time.sleep(60)
        """#
}
