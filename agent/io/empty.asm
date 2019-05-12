;;; Put a number on the stack identifying which IO engine this is.  Each IO layer
;;; needs to have its own unique ID.  This allows payloads to make decisions
;;; based on the configured IO.
	
start_def ASM, engine, "engine"
end_def engine

;;; This function will be called before any IO is performed.  This can be used to
;;; set up streams, initialize IO layer global variables, make network connections,
;;; etc.
	
start_def ASM, initio, "initio"
end_def initio
	
;;; Take a value from the stack and emit it to the output stream as a single byte.

start_def ASM, emit, "emit"
end_def emit
	
;;; Read a single byte from the input stream and put its value on top of the stkack.
	
start_def ASM, key, "key"
end_def key

;;; Given a buffer and length, send multiple bytes to the output stream.  This is
;;; largely provided as a convenience for situations where IO can be optimized
;;; for block communications.

start_def ASM, type, "type"
end_def type

;;; Enable and disable echoing of input to the output stream.  Some IO
;;; layers may prefer to allow this to be configurable.  Leave them empty
;;; if they don't make sense for your IO layer.
	
start_def ASM, echooff, "-echo"
end_def echooff

start_def ASM, echoon, "+echo"
end_def echoon

start_def ASM, setecho, "!echo"
end_def setecho

