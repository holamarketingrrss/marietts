<#
  Optimiza imágenes para la landing de Mariett's Flavors.
  - Convierte a WebP
  - Reduce el lado más largo a un máximo (por defecto 2000 px)
  - Quita metadatos y corrige la rotación de fotos de cámara/móvil
  - Si una imagen sigue pesando más del objetivo, baja la calidad poco a poco

  Requiere ImageMagick. Si no lo tienes, el script te dice cómo instalarlo.

  USO (desde PowerShell, en la carpeta donde está este archivo):
    .\optimizar-imagenes.ps1 -Origen "C:\ruta\a\tus\fotos"

  Opciones:
    -Origen      Carpeta con las imágenes originales (por defecto: carpeta actual)
    -Destino     Carpeta donde se guardan los WebP (por defecto: <Origen>\webp)
    -MaxLado     Lado más largo en px (por defecto 2000; para galería basta 1200)
    -Calidad     Calidad WebP inicial 0-100 (por defecto 80)
    -MaxKB       Peso objetivo por imagen en KB (por defecto 400)
#>

param(
  [string]$Origen  = (Get-Location).Path,
  [string]$Destino = "",
  [int]$MaxLado    = 2000,
  [int]$Calidad    = 80,
  [int]$MaxKB      = 400
)

$ErrorActionPreference = "Continue"

# --- Comprobar ImageMagick ---
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  Write-Host ""
  Write-Host "No se encontró ImageMagick." -ForegroundColor Red
  Write-Host "Instálalo con este comando y luego cierra y vuelve a abrir PowerShell:" -ForegroundColor Yellow
  Write-Host "  winget install ImageMagick.ImageMagick" -ForegroundColor Cyan
  Write-Host "(o descárgalo de https://imagemagick.org/script/download.php#windows)"
  exit 1
}

if (-not (Test-Path -LiteralPath $Origen)) {
  Write-Host "La carpeta de origen no existe: $Origen" -ForegroundColor Red
  exit 1
}
$Origen = (Resolve-Path -LiteralPath $Origen).Path

if ([string]::IsNullOrWhiteSpace($Destino)) { $Destino = Join-Path $Origen "webp" }
New-Item -ItemType Directory -Force -Path $Destino | Out-Null

$extensiones = @(".jpg", ".jpeg", ".png", ".tif", ".tiff", ".heic", ".heif", ".bmp", ".psd", ".webp", ".gif")
$archivos = Get-ChildItem -LiteralPath $Origen -File |
  Where-Object { $extensiones -contains $_.Extension.ToLower() } |
  Sort-Object Name

if ($archivos.Count -eq 0) {
  Write-Host "No se encontraron imágenes en $Origen" -ForegroundColor Yellow
  exit 0
}

Write-Host ""
Write-Host "Procesando $($archivos.Count) imágenes -> $Destino" -ForegroundColor Cyan
Write-Host "Máx. $MaxLado px · calidad inicial $Calidad · objetivo $MaxKB KB"
Write-Host ""

$totalAntes = 0
$totalDespues = 0
$i = 0

foreach ($f in $archivos) {
  $i++
  $salida = Join-Path $Destino ($f.BaseName + ".webp")

  # En PSD/TIFF multicapa se usa solo la imagen compuesta ([0])
  $entrada = $f.FullName
  if (@(".psd", ".tif", ".tiff", ".gif") -contains $f.Extension.ToLower()) { $entrada = "$($f.FullName)[0]" }

  $q = $Calidad
  $ok = $false
  while (-not $ok) {
    $argumentos = @(
      $entrada,
      "-auto-orient",
      "-resize", "$($MaxLado)x$($MaxLado)>",
      "-strip",
      "-colorspace", "sRGB",
      "-quality", "$q",
      "-define", "webp:method=6",
      $salida
    )
    & magick @argumentos 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $salida)) {
      Write-Host ("[{0}/{1}] ERROR al convertir {2}" -f $i, $archivos.Count, $f.Name) -ForegroundColor Red
      break
    }
    $kb = (Get-Item -LiteralPath $salida).Length / 1KB
    if ($kb -le $MaxKB -or $q -le 55) { $ok = $true } else { $q -= 5 }
  }

  if ($ok) {
    $antesMB = $f.Length / 1MB
    $totalAntes += $f.Length
    $totalDespues += (Get-Item -LiteralPath $salida).Length
    Write-Host ("[{0}/{1}] {2}  {3:N1} MB -> {4:N0} KB  (calidad {5})" -f $i, $archivos.Count, $f.Name, $antesMB, $kb, $q) -ForegroundColor Green
  }
}

Write-Host ""
Write-Host ("Listo. Total: {0:N1} MB -> {1:N1} MB" -f ($totalAntes / 1MB), ($totalDespues / 1MB)) -ForegroundColor Cyan
Write-Host "Los originales no se modificaron. Los WebP están en: $Destino"
