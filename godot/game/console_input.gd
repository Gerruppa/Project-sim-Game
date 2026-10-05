class_name ConsoleInput
extends RefCounted
## Reads the player's answers from standard input, one line at a time.
##
## Reads byte by byte: Git Bash hands Windows programs a pipe, and a pipe
## read of a whole buffer would wait for 1024 bytes instead of Enter
## (OS.read_string_from_stdin docs). Measured: Enter, CRLF and Polish
## letters all arrive correctly this way.


## The next line without its line break, or null when input has ended.
static func read_line() -> Variant:
	var bytes := PackedByteArray()
	while true:
		var chunk := OS.read_buffer_from_stdin(1)
		if chunk.is_empty():
			return null if bytes.is_empty() else bytes.get_string_from_utf8()
		if chunk[0] == 10:
			break
		if chunk[0] != 13:
			bytes.append(chunk[0])
	return bytes.get_string_from_utf8()
