$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8000
$logPath = Join-Path $root "server-log.txt"
"Starting server at $(Get-Date -Format s) from $root" | Set-Content -LiteralPath $logPath

try {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
  $listener.Start()
  "Listening on port $port" | Add-Content -LiteralPath $logPath
}
catch {
  "Startup error: $($_.Exception.Message)" | Add-Content -LiteralPath $logPath
  throw
}

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"
  ".png" = "image/png"
  ".jpg" = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".gif" = "image/gif"
  ".svg" = "image/svg+xml"
}

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
    $requestLine = $reader.ReadLine()

    while (($line = $reader.ReadLine()) -ne $null -and $line -ne "") {
      continue
    }

    $urlPath = "/"
    if ($requestLine -match "^[A-Z]+\s+([^\s]+)") {
      $urlPath = $Matches[1].Split("?")[0]
    }

    $requestPath = [System.Uri]::UnescapeDataString($urlPath.TrimStart("/"))
    if ([string]::IsNullOrWhiteSpace($requestPath)) {
      $requestPath = "index.html"
    }

    $candidate = Join-Path $root $requestPath
    $fullPath = [System.IO.Path]::GetFullPath($candidate)
    $rootPath = [System.IO.Path]::GetFullPath($root)

    if (-not $fullPath.StartsWith($rootPath) -or -not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
      $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
      $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      $stream.Write($body, 0, $body.Length)
      continue
    }

    $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
    $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $header = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    $stream.Write($bytes, 0, $bytes.Length)
  }
  finally {
    $client.Close()
  }
}
