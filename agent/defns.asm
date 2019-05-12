dict:
%define link 1	      ; indicates end of list
	              ; we'll later check this when updating pointers
%macro start_def 3
  %strlen namelen %3
	global code_%2
def_%2:	dq link
  %assign link def_%2 - core	
	db %1
	dd end_%2 - code_%2
	dd code_%2 - def_%2
	db namelen
name_%2:
	db %3			; name as ASCII
code_%2:	
%endmacro	

%macro end_def 1
end_%1:	 ret
%endmacro	

	
