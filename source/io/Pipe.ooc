import native/[PipeUnix, PipeWin32]
import io/[Reader, Writer]

Pipe: abstract class {
	eof := false
	new: static func -> This {
		version(unix || apple) {
			return PipeUnix new() as This
		}
		version(windows) {
			return PipeWin32 new() as This
		}
		Exception new(This, "Unsupported platform!\n") throw()
		null
	}
	read: func ~char -> Char {
		c: Char
		howmuch := read(c& as CString, 1)

		if (howmuch == -1) return '\0'
		c
	}
	read: func ~string (len: Int) -> String {
		buf := gc_malloc(len + 1) as CString
		howmuch := read(buf, len)

		if (howmuch == -1) return null // eof!

		// make sure it's 0-terminated
		buf[howmuch] = '\0'
		return buf toString()
	}
	read: func ~buffer (buf: Buffer) -> Int {
		bytesRead := read(buf data, buf capacity)
		if (bytesRead >= 0) {
			buf setLength(bytesRead)
		}
		bytesRead
	}
	read: abstract func ~cstring (buf: CString, len: Int) -> Int
	write: func ~string (str: String) -> Int {
		write(str _buffer data, str length())
	}
	write: abstract func (data: CString, len: Int) -> Int
	// 'r' = close in reading, 'w' = close in writing
	close: abstract func (mode: Char) -> Int
	close: abstract func ~both
	setNonBlocking: func ~both {
		setNonBlocking('r')
		setNonBlocking('w')
	}
	setNonBlocking: func (end: Char) {
		raise("This platform doesn't support non-blocking pipe I/O.")
	}
	SetBlocking: func ~both {
		setBlocking('r')
		setBlocking('w')
	}
	setBlocking: func (end: Char) {
		raise("This platform doesn't support blocking pipe I/O.")
	}
	eof?: func -> Bool {
		eof
	}
	reader: func -> PipeReader {
		PipeReader new(this)
	}
	writer: func -> PipeWriter {
		PipeWriter new(this)
	}
}

PipeReader: class extends Reader {
	pipe: Pipe
	init: func (=pipe)
	read: func (chars: CString, offset: Int, count: Int) -> SizeT {
		bytesRead := pipe read(chars + offset, count)
		// the semantics of Reader read() don't specify negative return values
		bytesRead >= 0 ? bytesRead : 0
	}
	read: func ~char -> Char {
		bytesRead := pipe read()
		// the semantics of Reader read() don't specify negative return values
		bytesRead >= 0 ? bytesRead : 0
	}
	hasNext?: func -> Bool {
		!pipe eof?()
	}
	mark: func -> Long {
		SeekingNotSupported new(This) throw()
		-1
	}
	seek: func (offset: Long, mode: SeekMode) -> Bool {
		SeekingNotSupported new(This) throw()
		false
	}
	close: func {
		pipe close('r')
	}
}

PipeWriter: class extends Writer {
	pipe: Pipe
	init: func (=pipe)
	write: func ~chr (chr: Char) {
		pipe write(chr&, 1)
	}
	write: func (bytes: CString, length: SizeT) -> SizeT {
		pipe write(bytes, length)
	}
	close: func {
		pipe close('w')
	}
}
