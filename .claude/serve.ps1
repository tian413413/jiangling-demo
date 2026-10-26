param([int]$Port = 8765, [string]$Root = (Join-Path $PSScriptRoot '..\public'))
# Minimal static file server for local preview (no Node/Python needed).
$Root = [IO.Path]::GetFullPath($Root)
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Serving $Root on http://localhost:$Port/"
$mime = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript'; '.css'='text/css'; '.png'='image/png'; '.webp'='image/webp'; '.jpg'='image/jpeg'; '.svg'='image/svg+xml'; '.json'='application/json'; '.ico'='image/x-icon' }
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if ($path -eq '/') { $path = '/index.html' }
    $fileFull = [IO.Path]::GetFullPath((Join-Path $Root ($path.TrimStart('/') -replace '/', '\')))
    if ($fileFull.StartsWith($Root) -and (Test-Path $fileFull -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($fileFull)
      $ext = [IO.Path]::GetExtension($fileFull).ToLower()
      $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
      $ctx.Response.Headers.Add('Cache-Control', 'no-store')
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Output ("200 " + $path)
    } else {
      $ctx.Response.StatusCode = 404
      $b = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
      $ctx.Response.OutputStream.Write($b, 0, $b.Length)
      Write-Output ("404 " + $path)
    }
  } catch {
    Write-Output ("ERR " + $_.Exception.Message)
  } finally {
    try { $ctx.Response.Close() } catch {}
  }
}
