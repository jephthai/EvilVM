def print_help()
  help = <<-eos
  EvilVM Server Help
  ------------------

  The EvilVM server provides an environment where you can receive connections from 
  EvilVM agents and interact with them.  The prompt works differently depending on
  your current context.  Initially, EvilVM server does nothing until an agent 
  connects back.  Once that happens, the immediate context is direct interaction
  with the compiler in that agent.

  To switch to the EvilVM control context, issue an 0x0b control character (^K).  
  Note that in most terminals, you will need to escape this character, yielding 
  the standard key sequence ^V^K.  Anything typed after this escape sequence will
  be interpreted by EvilVM as a server command.

  The following commands are supported:

  load this command will load a Forth code sample from the 'samples' 
  directory.  This is analogous to loading a library.  The server keeps track of
  which samples have been sent to each agent, and will not send the same file
  twice.

  loadf if you really want to send a file no matter what (e.g., a second time,
  such as when you're doing library development), use this command.  It will ignore
  the check that prevents sending a sample file more than once.

  kill [ID] terminate the indicated agent session.  Each session is assigned 
  a numeric ID that can be found using the 'list' command.

  switch [ID] switch the interactive context to the indicated session.

  list print out a list of all existing agent sessions.

  upload [PATH] will upload a file from the EvilVM server host to the current
  agent session.  This does require that the network payload is loaded and the 
  agent supports the 'upload' word.

  quit will terminate the EvilVM server and all connected agents.

  help prints this help output.  
eos

  puts(help.gsub("", "\x1b[1m").gsub("", "\x1b[22m"))
end
