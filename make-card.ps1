<#
  make-card.ps1  —  Generate an NFC business-card folder (index.html + contact.vcf)
  for an LMI Group Investments team member.

  USAGE (run from inside the BusinessCards folder):

    .\make-card.ps1 -Name "John Smith" -Title "Account Manager" `
                    -Phone "+61 400 123 456" -Email "john@lmigi.com.au" `
                    -LinkedIn "https://au.linkedin.com/in/john-smith"

  - LinkedIn is OPTIONAL. Omit it and the LinkedIn button is left off that card.
  - Output goes to a new folder named after the person, e.g.  .\john-smith\
    containing index.html + contact.vcf, ready to upload to GitHub.
  - The LMI logo is embedded automatically (no internet needed).
#>

param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$Title,
  [Parameter(Mandatory=$true)][string]$Phone,
  [Parameter(Mandatory=$true)][string]$Email,
  [string]$LinkedIn = "",
  [string]$Org = "LMI Group Investments",
  [string]$Slug = "",
  [string]$LogoPath = "$PSScriptRoot\logo colour no background.png",
  [string]$TemplatePath = "$PSScriptRoot\_template.html"
)

$ErrorActionPreference = "Stop"

# --- helpers ---------------------------------------------------------------
function Get-Slug([string]$s){
  $t = $s.ToLower() -replace "[^a-z0-9]+","-"
  return ($t.Trim("-"))
}
function Get-Initials([string]$s){
  $parts = $s -split "\s+" | Where-Object { $_ -ne "" }
  if($parts.Count -ge 2){ return ($parts[0].Substring(0,1) + $parts[-1].Substring(0,1)).ToUpper() }
  elseif($parts.Count -eq 1){ return $parts[0].Substring(0,[Math]::Min(2,$parts[0].Length)).ToUpper() }
  return "?"
}
# split "John Michael Smith" -> Family=Smith, Given=John, Additional=Michael
function Get-NameParts([string]$s){
  $parts = $s -split "\s+" | Where-Object { $_ -ne "" }
  $family=""; $given=""; $additional=""
  if($parts.Count -eq 1){ $given=$parts[0] }
  elseif($parts.Count -eq 2){ $given=$parts[0]; $family=$parts[1] }
  else{ $given=$parts[0]; $family=$parts[-1]; $additional=($parts[1..($parts.Count-2)] -join " ") }
  return @{ Family=$family; Given=$given; Additional=$additional }
}

if([string]::IsNullOrWhiteSpace($Slug)){ $Slug = Get-Slug $Name }
$initials = Get-Initials $Name
$telHref  = "+" + ((($Phone) -replace "[^0-9]","")) # strip everything but digits, keep leading +
if(-not $Phone.Trim().StartsWith("+")){ $telHref = (($Phone) -replace "[^0-9]","") } # local number, no +

# --- build the logo data URI ----------------------------------------------
if(-not (Test-Path $LogoPath)){ throw "Logo not found at: $LogoPath" }
$logoUri = "data:image/png;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($LogoPath))

# --- read + fill the HTML template ----------------------------------------
if(-not (Test-Path $TemplatePath)){ throw "Template not found at: $TemplatePath" }
$html = [IO.File]::ReadAllText($TemplatePath)

# Strip the LinkedIn block if no LinkedIn supplied
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
  Replace("{{LOGO}}",        $logoUri)

# --- build the vCard (vCard 3.0, CRLF line endings) ------------------------
$np = Get-NameParts $Name
$vcfLines = @(
  "BEGIN:VCARD",
  "VERSION:3.0",
  "N:$($np.Family);$($np.Given);$($np.Additional);;",
  "FN:$Name",
  "ORG:$Org",
  "TITLE:$Title",
  "TEL;TYPE=CELL,VOICE:$telHref",
  "EMAIL;TYPE=INTERNET:$Email"
)
if(-not [string]::IsNullOrWhiteSpace($LinkedIn)){ $vcfLines += "URL:$LinkedIn" }
$vcfLines += "END:VCARD"
$vcf = ($vcfLines -join "`r`n") + "`r`n"

# --- write output ----------------------------------------------------------
$outDir = Join-Path $PSScriptRoot $Slug
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $outDir "index.html"), $html, $utf8)
[IO.File]::WriteAllText((Join-Path $outDir "contact.vcf"), $vcf, $utf8)

Write-Host ""
Write-Host "  Card created for $Name" -ForegroundColor Green
Write-Host "  Folder : $outDir"
Write-Host "  Files  : index.html  +  contact.vcf"
Write-Host "  URL    : https://YOURNAME.github.io/card/$Slug/" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next: upload the '$Slug' folder into your GitHub 'card' repo," -ForegroundColor DarkGray
Write-Host "        then write that URL to the NFC tag." -ForegroundColor DarkGray
Write-Host ""
