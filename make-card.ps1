<#
  make-card.ps1  —  Generate an NFC business-card folder (index.html + contact.vcf)
  for an LMI Group Investments team member.

  USAGE (run from inside the BusinessCards folder):

    .\make-card.ps1 -Name "John Smith" -Title "Account Manager" `
                    -Phone "+61 400 123 456" -Email "john@lmigi.com.au" `
                    -LinkedIn "https://au.linkedin.com/in/john-smith" `
                    -Headshot ".\john.jpg"

    # Holly's own card (output straight to the repo root):
    .\make-card.ps1 -Name "Holly Prior" -Title "Project Manager" `
                    -Phone "+61 480 626 159" -Email "holly@lmigi.com.au" `
                    -LinkedIn "https://au.linkedin.com/in/holly-prior" `
                    -Headshot ".\holly.jpg" -OutName "."

  Notes:
    - -Headshot is OPTIONAL. If omitted, the card shows a coloured initials circle.
    - -LinkedIn is OPTIONAL. If omitted, the LinkedIn button is left off.
    - The shared project photo (-Background, default Background.jpeg) animates behind
      the frosted-glass card. The LMI logo + headshot are embedded automatically.
    - -OutName sets the output folder ("." = repo root, otherwise a subfolder).
#>

param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$Title,
  [Parameter(Mandatory=$true)][string]$Phone,
  [Parameter(Mandatory=$true)][string]$Email,
  [string]$LinkedIn = "",
  [string]$Headshot = "",
  [string]$Org = "LMI Group Investments",
  [string]$Slug = "",
  [string]$OutName = "",
  [string]$LogoPath = "$PSScriptRoot\logo colour no background.png",
  [string]$Background = "$PSScriptRoot\Background.jpeg",
  [string]$TemplatePath = "$PSScriptRoot\_template.html",
  [switch]$Publish
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# --- helpers ---------------------------------------------------------------
function Get-Slug([string]$s){ (($s.ToLower() -replace "[^a-z0-9]+","-").Trim("-")) }

function Get-Initials([string]$s){
  $parts = $s -split "\s+" | Where-Object { $_ -ne "" }
  if($parts.Count -ge 2){ return ($parts[0].Substring(0,1) + $parts[-1].Substring(0,1)).ToUpper() }
  elseif($parts.Count -eq 1){ return $parts[0].Substring(0,[Math]::Min(2,$parts[0].Length)).ToUpper() }
  return "?"
}

function Get-NameParts([string]$s){
  $parts = $s -split "\s+" | Where-Object { $_ -ne "" }
  $family=""; $given=""; $additional=""
  if($parts.Count -eq 1){ $given=$parts[0] }
  elseif($parts.Count -eq 2){ $given=$parts[0]; $family=$parts[1] }
  else{ $given=$parts[0]; $family=$parts[-1]; $additional=($parts[1..($parts.Count-2)] -join " ") }
  return @{ Family=$family; Given=$given; Additional=$additional }
}

function Get-DataUri([string]$path){
  $ext = ([IO.Path]::GetExtension($path)).TrimStart(".").ToLower()
  $mime = if($ext -eq "png"){"image/png"} elseif($ext -in @("jpg","jpeg")){"image/jpeg"} elseif($ext -eq "svg"){"image/svg+xml"} else {"application/octet-stream"}
  return "data:$mime;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
}

# Center-crop to a square and re-encode as JPEG (keeps headshots small when inlined)
function Get-SquareJpegDataUri([string]$path,[int]$size=480,[int]$quality=82){
  $img = [System.Drawing.Image]::FromFile($path)
  try{
    $side = [Math]::Min($img.Width, $img.Height)
    $sx = [int](($img.Width - $side)/2); $sy = [int](($img.Height - $side)/2)
    $bmp = New-Object System.Drawing.Bitmap $size,$size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode  = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode    = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $dest = New-Object System.Drawing.Rectangle 0,0,$size,$size
    $g.DrawImage($img,$dest,$sx,$sy,$side,$side,[System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [int64]$quality)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms,$enc,$ep)
    $bmp.Dispose()
    return "data:image/jpeg;base64," + [Convert]::ToBase64String($ms.ToArray())
  } finally { $img.Dispose() }
}

# --- derive fields ---------------------------------------------------------
if([string]::IsNullOrWhiteSpace($Slug)){ $Slug = Get-Slug $Name }
$initials = Get-Initials $Name
if($Phone.Trim().StartsWith("+")){ $telHref = "+" + (($Phone) -replace "[^0-9]","") }
else { $telHref = (($Phone) -replace "[^0-9]","") }

# --- assets ----------------------------------------------------------------
if(-not (Test-Path $LogoPath)){ throw "Logo not found at: $LogoPath" }
if(-not (Test-Path $Background)){ throw "Background photo not found at: $Background" }
$logoUri = Get-DataUri $LogoPath
$bgUri   = Get-DataUri $Background

# --- template --------------------------------------------------------------
if(-not (Test-Path $TemplatePath)){ throw "Template not found at: $TemplatePath" }
$html = [IO.File]::ReadAllText($TemplatePath)

# headshot: keep one of the two avatar blocks
if(-not [string]::IsNullOrWhiteSpace($Headshot)){
  if(-not (Test-Path $Headshot)){ throw "Headshot not found at: $Headshot" }
  $hsUri = Get-SquareJpegDataUri $Headshot 480 82
  $html  = $html.Replace("<!--HS-->","").Replace("<!--/HS-->","")
  $html  = [regex]::Replace($html, "<!--NOHS-->.*?<!--/NOHS-->", "", "Singleline")
  $html  = $html.Replace("{{HEADSHOT}}", $hsUri)
}else{
  $html  = [regex]::Replace($html, "<!--HS-->.*?<!--/HS-->", "", "Singleline")
  $html  = $html.Replace("<!--NOHS-->","").Replace("<!--/NOHS-->","")
}

# LinkedIn: keep or strip its button
if([string]::IsNullOrWhiteSpace($LinkedIn)){
  $html = [regex]::Replace($html, "<!--LI-->.*?<!--/LI-->", "", "Singleline")
}else{
  $html = $html.Replace("<!--LI-->","").Replace("<!--/LI-->","")
}

$html = $html.
  Replace("{{NAME}}",        $Name).
  Replace("{{TITLE}}",       $Title).
  Replace("{{ORG}}",         $Org).
  Replace("{{LINKEDIN}}",    $LinkedIn).
  Replace("{{TEL_HREF}}",    $telHref).
  Replace("{{TEL_DISPLAY}}", $Phone).
  Replace("{{EMAIL}}",       $Email).
  Replace("{{INITIALS}}",    $initials).
  Replace("{{BACKGROUND}}",  $bgUri).
  Replace("{{LOGO}}",        $logoUri)

# --- vCard (3.0, CRLF, stored verbatim) ------------------------------------
$np = Get-NameParts $Name
$vcfLines = @(
  "BEGIN:VCARD","VERSION:3.0",
  "N:$($np.Family);$($np.Given);$($np.Additional);;",
  "FN:$Name","ORG:$Org","TITLE:$Title",
  "TEL;TYPE=CELL,VOICE:$telHref",
  "EMAIL;TYPE=INTERNET:$Email"
)
if(-not [string]::IsNullOrWhiteSpace($LinkedIn)){ $vcfLines += "URL:$LinkedIn" }
$vcfLines += "END:VCARD"
$vcf = ($vcfLines -join "`r`n") + "`r`n"

# --- write -----------------------------------------------------------------
if([string]::IsNullOrWhiteSpace($OutName)){ $OutName = $Slug }
if($OutName -eq "."){ $outDir = $PSScriptRoot } else { $outDir = Join-Path $PSScriptRoot $OutName }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $outDir "index.html"), $html, $utf8)
[IO.File]::WriteAllText((Join-Path $outDir "contact.vcf"), $vcf, $utf8)

$urlPath = if($OutName -eq "."){ "" } else { "$OutName/" }
Write-Host ""
Write-Host "  Card created for $Name" -ForegroundColor Green
Write-Host "  Folder : $outDir"
Write-Host "  Headshot: $([bool]$Headshot)   LinkedIn: $([bool]$LinkedIn)"
Write-Host "  URL    : https://hollylmi.github.io/card/$urlPath" -ForegroundColor Cyan
Write-Host ""

# --- optional: publish straight to GitHub Pages ----------------------------
if($Publish){
  Write-Host "  Publishing to GitHub..." -ForegroundColor Yellow
  Push-Location $PSScriptRoot
  try{
    git add -A
    git -c core.safecrlf=false commit -m "Add/update card for $Name" 2>&1 | Out-Null
    git push origin main 2>&1 | Out-Null
    Write-Host "  Published. Live in ~1 minute at:" -ForegroundColor Green
    Write-Host "  https://hollylmi.github.io/card/$urlPath" -ForegroundColor Cyan
    Write-Host ""
  } finally { Pop-Location }
}
