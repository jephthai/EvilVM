\ require structs.fth

{ ." 

  logons.fth
  
  Enumerate logon sessions from the LSA and print out useful
  information about them.  This uses the interface exported
  by Secur32.dll, and requires that structures be loaded into
  the language.
  
  Run print-sessions to see a listing.

" ETX emit }!

loadlib secur32.dll
value secur32

secur32 2 dllfun LsaEnumerateLogonSessions LsaEnumerateLogonSessions
secur32 2 dllfun LsaGetLogonSessionData LsaGetLogonSessionData
secur32 1 dllfun LsaFreeReturnBuffer LsaFreeReturnBuffer

variable lsa-count
variable lsa-list

: word-align 7  + $fffffff8 and ;
: para-align 15 + $fffffff0 and ;

struct SID
  1 field Revision
  1 field SubAuthorityCount
  6 field IdentifierAuthority
  4 field SubAuthority
end-struct

struct LSA_UNICODE_STRING
  2 field Length
  2 field MaximumLength
  word-align
  8 field Buffer
end-struct

struct LSA_LAST_INTER_LOGON_INFO
  8 field LastSuccessfulLogon
  8 field LastFailedLogon
  4 field FailedAttemptCountSinceLastSuccessfulLogon
  word-align
end-struct

struct SECURITY_LOGON_SESSION_DATA
  4                         field Size
  8                         field LogonId
  word-align
  LSA_UNICODE_STRING        field UserName
  LSA_UNICODE_STRING        field LogonDomain
  LSA_UNICODE_STRING        field AuthenticationPackage
  4                         field LogonType
  4                         field Session
  8                         field Sid
  8                         field LogonTime
  LSA_UNICODE_STRING        field LogonServer
  LSA_UNICODE_STRING        field DnsDomainName
  LSA_UNICODE_STRING        field Upn
  4                         field UserFlags
  word-align
  LSA_LAST_INTER_LOGON_INFO field LastLogonInfo
  LSA_UNICODE_STRING        field LogonScript
  LSA_UNICODE_STRING        field ProfilePath
  LSA_UNICODE_STRING        field HomeDirectory
  LSA_UNICODE_STRING        field HomeDirectoryDrive
  8                         field LogoffTime
  8                         field KickOffTime
  8                         field PasswordLastSet
  8                         field PasswordCanChange
  8                         field PasswordMustChange
  para-align
end-struct

: ur.type ( addr u len -- )
  2dup swap 2 / - >r drop type
  r> dup 0 > if spaces else drop then
;

: .uni dup Buffer @ swap Length w@ type ;
: @uni dup Buffer @ swap Length w@ ;

: get-list lsa-count lsa-list LsaEnumerateLogonSessions ;

variable lsa-session

: get-session lsa-session LsaGetLogonSessionData ;

: print-sessions
  .pre
  get-list if return then 
  +rev ." #     Package          LogonServer      DnsDomainName            Username" 24 spaces -rev cr
  lsa-count @ 0 do
    i -bold 6 .r +bold

    \ get address of logon session ID
    lsa-list @ i cells + get-session dup 0= if drop
    
      \ print some info about it
      lsa-session @ AuthenticationPackage @uni 16 ur.type space
      lsa-session @ LogonServer           @uni 16 ur.type space
      lsa-session @ DnsDomainName         @uni 24 ur.type space
      lsa-session @ LogonDomain .uni
      [char] \ emit
      lsa-session @ UserName .uni cr

      \ clean up
      lsa-session @ LsaFreeReturnBuffer if .err reset then
    else
      ." error: " . 
      cr
    then
  loop

  \ clean up
  lsa-list @ LsaFreeReturnBuffer if .err reset then

  .post
;
