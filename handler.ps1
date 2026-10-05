param([string]$Url)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$log  = Join-Path $base 'handler.log'

function Log($m) { "$(Get-Date -Format s)  $m" | Add-Content -Path $log -Encoding UTF8 }

try {
    Log "Enlace recibido: $Url"
    Add-Type -AssemblyName System.Web

    $uri    = [System.Uri]$Url
    $query  = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
    $accion = $uri.Host
    $romId  = $uri.AbsolutePath.Trim('/')

    if ($accion -ne 'play' -or $romId -notmatch '^\d+$') { throw "Enlace no valido: $Url" }

    $cfg = Get-Content (Join-Path $base 'config.json') -Raw | ConvertFrom-Json
    $server = $cfg.server.TrimEnd('/')
    if ($query['server']) { $server = $query['server'].TrimEnd('/') }

    $cred = "$($env:ROMM_USER):$($env:ROMM_PASS)"
    $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cred))
    $rom  = Invoke-RestMethod -Uri "$server/api/roms/$romId" -Headers @{ Authorization = $auth }

    $plataforma = $rom.platform_fs_slug
    $archivo    = $rom.fs_name
    Log "Juego $romId -> plataforma=$plataforma archivo=$archivo"

    $p = $cfg.platforms.$plataforma
    if (-not $p) { throw "No hay configuracion para la plataforma '$plataforma'" }

    if ($cfg.rom_source.mode -eq 'share') {
        $romPath = Join-Path (Join-Path $cfg.rom_source.share_root $plataforma) $archivo
        if (-not (Test-Path -LiteralPath $romPath)) { throw "No existe la ROM: $romPath" }
    } else {
        throw "Modo '$($cfg.rom_source.mode)' aun no implementado"
    }
    Log "Ruta de la ROM: $romPath"

    switch ($p.action) {
        'emulator' {
            $argumentos = $p.args.Replace('{rom_path}', $romPath)
            Log "Lanzando: $($p.command) $argumentos"
            Start-Process -FilePath $p.command -ArgumentList $argumentos -Wait
            Log "Emulador cerrado"
        }
        default { throw "Accion '$($p.action)' aun no implementada" }
    }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'RomM Local Launcher') | Out-Null
}