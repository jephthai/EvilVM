loadlib shlwapi.dll
value shlwapi

{ ." 

  shared-memory.fth
  
  Provides a basic interface for using shared memory between processes.
  This uses the interface provided by SHLWAPI.DLL, which really
  simplifies the process.
  
  To create shared memory between processes pid1 and pid2, use the 
  following steps in pid1:
  
   (1) Run <size> <pid2> make-share to get a handle in both processes
   (2) Run <handle> <pid2> get-share for a pointer to the region
   (3) Note the value of the handle
  
  Then in process pid2, using the same handle value:
  
   (1) Run <handle> <pid1> get-share for a pointer to the same region
  
  If you ever want to stop using the region, release it as follows:
  
   (1) Run <addr> release-share

" ETX emit }!
 
\ HANDLE AllocShared(LPCVOID lpData, DWORD dwSize, DWORDdwProcessId)
\ BOOL FreeShared(HANDLE hData, DWORD dwProcessId)
\ LPVOID LockShared(HANDLE hData, DWORD dwProcessId)
\ BOOL UnlockShared (LPVOID lpData)

shlwapi 3 dllfun AllocShared SHAllocShared
shlwapi 2 dllfun FreeShared SHFreeShared
shlwapi 2 dllfun LockShared SHLockShared
shlwapi 1 dllfun UnlockShared SHUnlockShared

2 value DUPLICATE_SAME_ACCESS
$40 value PROCESS_DUP_HANDLE
$10000000 value GENERIC_ALL

: make-share ( size pid -- handle )
  0 -rot AllocShared ;

: get-share ( handle pid -- addr )
  LockShared ;

: release-share ( addr -- )
  UnlockShared ;
