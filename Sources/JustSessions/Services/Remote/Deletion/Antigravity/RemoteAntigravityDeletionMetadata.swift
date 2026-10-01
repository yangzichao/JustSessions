enum RemoteAntigravityDeletionMetadata {
    /// Decode only the workspace URI needed to verify the selected session on its actual host.
    static let script = """
        def field(data, wanted):
            position = 0
            def varint():
                nonlocal position
                value = 0
                for shift in range(0, 70, 7):
                    if position >= len(data): raise ValueError('Truncated session metadata')
                    byte = data[position]; position += 1
                    value |= (byte & 127) << shift
                    if byte < 128: return value
                raise ValueError('Invalid session metadata')
            while position < len(data):
                key = varint(); number, wire = key >> 3, key & 7
                if wire == 0: varint()
                elif wire in (1, 5): position += 8 if wire == 1 else 4
                elif wire == 2:
                    length = varint()
                    if length > len(data) - position: raise ValueError('Truncated session metadata')
                    value = data[position:position + length]; position += length
                    if number == wanted: return value
                else: raise ValueError('Invalid session metadata')
            raise ValueError('Missing workspace metadata')
        """
}
