\ require named-locals.fth

: volume ( width height depth -- volume )
  locals width height depth
	 width @ height @ * depth @ * 
  end-locals
;
