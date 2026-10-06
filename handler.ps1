param([string]$Url)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$log  = Join-Path $base 'handler.log'

function Log($m) { "$(Get-Date -Format s)  $m" | Add-Content -Path $log -Encoding UTF8 }

function Get-RomJson($server, $auth, $romId) {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri "$server/api/roms/$romId" -Headers @{ Authorization = $auth }
    $texto = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    return ($texto | ConvertFrom-Json)
}

function Get-RomPath($cfg, $server, $auth, $romId, $plataforma, $archivo) {
    $modo = $cfg.rom_source.mode
    if ($modo -eq 'share') {
        $ruta = Join-Path (Join-Path $cfg.rom_source.share_root $plataforma) $archivo
        if (-not (Test-Path -LiteralPath $ruta)) { throw "No existe la ROM: $ruta" }
        return $ruta
    }
    if ($modo -eq 'download') {
        $dir = Join-Path (Join-Path $cfg.rom_source.cache_dir $plataforma) $romId
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $ruta = Join-Path $dir $archivo
        if (-not (Test-Path -LiteralPath $ruta)) {
            $nombre = [System.Uri]::EscapeDataString($archivo)
            $urlDescarga = "$server/api/roms/$romId/content/$nombre"
            Log "Descargando: $urlDescarga"
            Invoke-WebRequest -UseBasicParsing -Uri $urlDescarga -Headers @{ Authorization = $auth } -OutFile $ruta
        } else {
            Log "Ya estaba en cache: $ruta"
        }
        return $ruta
    }
    throw "Modo '$modo' no reconocido"
}

function Find-RomFile($carpeta, $extensiones) {
    if (-not (Test-Path -LiteralPath $carpeta)) { return $null }
    return Get-ChildItem -LiteralPath $carpeta -Recurse -File |
        Where-Object { $extensiones -contains $_.Extension.ToLower() } |
        Select-Object -First 1
}

function Expand-IfZip($ruta, $p, $cfg, $romId, $plataforma) {
    $esZip = ([System.IO.Path]::GetExtension($ruta).ToLower() -eq '.zip')
    if (-not $esZip -or -not $p.extract_zip) { return $ruta }

    $exts = @($p.rom_extensions | ForEach-Object { $_.ToLower() })
    $dest = Join-Path (Join-Path (Join-Path $cfg.rom_source.cache_dir 'extraidos') $plataforma) $romId

    $found = Find-RomFile $dest $exts
    if (-not $found) {
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Log "Extrayendo $ruta en $dest (puede tardar)"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ruta, $dest)
        $found = Find-RomFile $dest $exts
    } else {
        Log "Ya estaba extraido: $($found.FullName)"
    }
    if (-not $found) { throw "El ZIP no contiene ninguno de: $($exts -join ', ')" }
    return $found.FullName
}

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

    $permitidos = @($cfg.allowed_servers)
    if ($permitidos.Count -gt 0 -and ($permitidos -notcontains $server)) {
        throw "Servidor no permitido: $server"
    }

    $cred = "$($env:ROMM_USER):$($env:ROMM_PASS)"
    $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cred))
    $rom  = Get-RomJson $server $auth $romId

    $plataforma = $rom.platform_fs_slug
    $archivo    = $rom.fs_name
    Log "Juego $romId -> plataforma=$plataforma archivo=$archivo"

    $p = $cfg.platforms.$plataforma
    if (-not $p) { throw "No hay configuracion para la plataforma '$plataforma'" }

    switch ($p.action) {
        'emulator' {
            $romPath = Get-RomPath $cfg $server $auth $romId $plataforma $archivo
            $romPath = Expand-IfZip $romPath $p $cfg $romId $plataforma
            Log "Ruta final de la ROM: $romPath"
            $argumentos = $p.args.Replace('{rom_path}', $romPath)
            Log "Lanzando: $($p.command) $argumentos"
            Start-Process -FilePath $p.command -ArgumentList $argumentos -Wait
            Log "Emulador cerrado"
        }
        'playnite' {
            if (-not $p.playnite_id -or $p.playnite_id -eq 'POR-DEFINIR') { throw "Falta playnite_id para '$plataforma'" }
            $destino = "playnite://playnite/start/$($p.playnite_id)"
            Log "Abriendo: $destino"
            Start-Process $destino
        }
        'script' {
            $romPath = Get-RomPath $cfg $server $auth $romId $plataforma $archivo
            Log "Ejecutando script: $($p.script)"
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p.script -RomId $romId -Platform $plataforma -RomPath $romPath
            Log "Script terminado (codigo $LASTEXITCODE)"
        }
        default { throw "Accion '$($p.action)' no reconocida" }
    }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'RomM Local Launcher') | Out-Null
}