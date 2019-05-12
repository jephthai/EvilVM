\ require structs.fth

{ ." 

Service interaction module.  Uses the ADVAPI32.DLL interface
for connecting to the service control manager and querying
its status.

Run list-services to see all services.
Use enum-services to get a buffer to service status array.

" ETX emit }!


advapi32 3 dllfun OpenSCManager OpenSCManagerA
advapi32 8 dllfun EnumServicesStatus EnumServicesStatusA

struct ENUM_SERVICE_STATUS
  8  field lpServiceName
  8  field lpDisplayName
  4  field dwServiceType
  4  field dwCurrentState
  4  field dwControlsAccepted
  4  field dwWin32ExitCode
  4  field dwServiceSpecificExitCode
  4  field dwCheckPoint
  4  field dwWaitHint
  4 + \ some padding for paragraph alignment
end-struct

variable svc-bytes
variable svc-count
variable svc-resume
variable svc-buffer
variable svc-size

$f003f value SC_MANAGER_ALL_ACCESS 
$0002  value SC_MANAGER_CREATE_SERVICE 
$0001  value SC_MANAGER_CONNECT 
$0004  value SC_MANAGER_ENUMERATE_SERVICE 
$0008  value SC_MANAGER_LOCK 
$0020  value SC_MANAGER_MODIFY_BOOT_CONFIG 
$0010  value SC_MANAGER_QUERY_LOCK_STATUS 

$0b value SERVICE_DRIVER
$02 value SERVICE_FILE_SYSTEM_DRIVER
$01 value SERVICE_KERNEL_DRIVER
$30 value SERVICE_WIN32
$10 value SERVICE_WIN32_OWN_PROCESS
$20 value SERVICE_WIN32_SHARE_PROCESS
$ff value SERVICE_ALL

1 value SERVICE_ACTIVE
2 value SERVICE_INACTIVE
3 value SERVICE_STATE_ALL

\ get a handle to the service control manager
: open-scm ( -- handle )
  0 0 SC_MANAGER_ENUMERATE_SERVICE OpenSCManager
  dup 0= if .err then ;

\ enumerate service listing
: enum-status ( handle type state -- bool )
  svc-buffer @ svc-size @
  svc-bytes svc-count svc-resume
  EnumServicesStatus ;

\ start state
: enum-init
  svc-buffer off
  svc-size off
;

: enum-services ( -- buffer )
  \ get the handle
  enum-init open-scm >r

  \ find out how big the buffer needs to be
  r@ SERVICE_ALL SERVICE_STATE_ALL enum-status

  \ allocate buffer
  svc-bytes @ dup svc-size !
  allocate svc-buffer !

  \ try again and get the data
  r@ SERVICE_ALL SERVICE_STATE_ALL enum-status

  \ reclaim the handle
  r> CloseHandle
  
  svc-buffer @
;

: list-services ( -- )
  .pre
  enum-services
  svc-count @ 0 do
    \ offset into the array
    dup i ENUM_SERVICE_STATUS * + 
    
    \ print the state
    dup dwCurrentState d@ 6 .r

    \ type of service
    dup dwServiceType d@ 6 hex .r dec

    \ get the names and print it
    dup lpServiceName @ c->str 32 r.type space
    dup lpDisplayName @ .cstring

    drop cr
  loop
  free .post
;
