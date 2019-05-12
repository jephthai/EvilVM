# EvilVM
EvilVM compiler for information security research tools.  The project is built around a native code Forth compiler that is deployed as a position independent shellcode. It provides a platform for remote code execution, useful in information security contexts.

Find documentation for EvilVM at [the doc site](http://evilvm.ninja).

The primary use case for EvilVM is to deploy the agent on a remote system, and interact with it. The language’s outer interpreter is presented as an interactive shell or REPL, and the system provides the capability to deliver code to the agent, which is compiled, and added to the hyperstatic global environment.

Technology choices are made with the project’s goals in mind:

  1. **Small, easily deployed payload:** the EvilVM agent is a position independent, x86_64 shellcode that weighs in somewhere between 5-10KB, depending on options and encapsulation.
  2. **Remote I/O streams:** the standard I/O paradigm for interacting with the language is via abstracted network-capable streams, allowing transport over TCP, HTTP, etc.
  3. **Low level access:** the runtime environment provides direct access to compiler internals, machine code, and direct memory interaction.
  4. **Native interoperability:** a simple C FFI is provided, making it easy to import DLLs, find exports, and wrap them with Forth function definitions.
  5. **Expressive language:** while Forth provides a ‘low floor’, functioning close to the assembly language level, it also offers a ‘high ceiling’, permitting runtime syntactic extension of the language, and is well-suited to metaprogramming techniques.
  6. **Infosec considerations:** generation of payloads supports different encoding and encapsulation schemes to fit in well with typical malicious delivery scenarios (exploits, injection, etc.).
