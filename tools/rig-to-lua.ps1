#Requires -Version 5.1
<#
  rig-to-lua.ps1  (ASCII only)

  Turns ONE rig inside a Roblox XML dump into a ready-to-paste Studio builder.

      powershell -ExecutionPolicy Bypass -File tools\rig-to-lua.ps1 ^
          -File "D:\DSH ROBLOX\doors_downloads\jeff f1.rbxlx" ^
          -Rig "Spider" -Name "Timothy" -Out "models\Timothy.build.lua"

  Why XML DOM and not regex: earlier regex versions broke twice.
    1) slicing "up to the next <Item class=Model>" truncated nested rigs
       (FigureAnimatedWelded lost 3 parts and all 3 decals)
    2) counting <Item>/</Item> broke when a child Script contained those
       literals inside a ProtectedString, and a bare IndexOf($Rig) matched
       an achievement string in Lua ("Spider") instead of the model
  A real XML parse cannot make those mistakes.

  Options:
      -Name <string>    model name in Studio (default: the rig name)
      -PlaceAt <string> "x,y,z" world position (default "0,10,0")
      -Decal <string>   "PartName=rbxassetid://123" to force a face decal
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$File,
    [Parameter(Mandatory)][string]$Rig,
    [string]$Out = '',
    [string]$Name = '',
    [string]$PlaceAt = '0,10,0',
    [string]$Decal = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $File)) { throw "file not found: $File" }
if ([string]::IsNullOrWhiteSpace($Out)) {
    $Out = Join-Path (Split-Path -Parent $PSScriptRoot) ("models\$Rig.build.lua")
}
if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $Rig }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$raw = [System.IO.File]::ReadAllText($File, $utf8)
if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty file: $File" }

Write-Host ("parsing XML ({0:N1} MB)..." -f ($raw.Length / 1MB)) -ForegroundColor DarkGray
$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $false
$doc.LoadXml($raw)
$raw = $null

# ---- locate the rig ------------------------------------------------------
$modelNode = $null
$allModels = $doc.SelectNodes("//Item[@class='Model']")
foreach ($m in $allModels) {
    $n = $m.SelectSingleNode("./Properties/string[@name='Name']")
    if ($null -eq $n) { continue }
    if ($n.InnerText -ne $Rig) { continue }
    if ($null -eq $m.SelectSingleNode(".//Item[@class='MeshPart']")) { continue }
    $modelNode = $m
    break
}
if ($null -eq $modelNode) { throw "rig '$Rig' not found (no Model with that Name that contains MeshParts) in $File" }

# ---- parts ---------------------------------------------------------------
$rows = New-Object System.Collections.Generic.List[string]
$partCount = 0

foreach ($p in $modelNode.SelectNodes(".//Item[@class='MeshPart']")) {
    $pn = $p.SelectSingleNode("./Properties/string[@name='Name']")
    $partName = if ($null -ne $pn) { $pn.InnerText } else { 'Part' }

    $pm = $p.SelectSingleNode("./Properties/Content[@name='MeshId']")
    if ($null -eq $pm) { continue }
    $mesh = ($pm.InnerText -replace '[^0-9]', '')
    if ([string]::IsNullOrWhiteSpace($mesh)) { continue }

    $sx = '1'; $sy = '1'; $sz = '1'
    $psz = $p.SelectSingleNode("./Properties/Vector3[@name='size']")
    if ($null -ne $psz) {
        $sx = $psz.SelectSingleNode("./X").InnerText
        $sy = $psz.SelectSingleNode("./Y").InnerText
        $sz = $psz.SelectSingleNode("./Z").InnerText
    }

    $vals = @()
    $pcf = $p.SelectSingleNode("./Properties/CoordinateFrame[@name='CFrame']")
    if ($null -ne $pcf) {
        foreach ($tag in @('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22')) {
            $node = $pcf.SelectSingleNode("./$tag")
            $vals += if ($null -ne $node) { $node.InnerText } else { '' }
        }
        if ($vals -contains '') { $vals = @() }
    }

    if ($vals.Count -eq 12) {
        $rows.Add(('			{{ "{0}", "{1}", {2}, {3}, {4}, {5}' -f $partName, $mesh, ($vals -join ', '), $sx, $sy, $sz))
    }
    else {
        $rows.Add(('			{{ "{0}", "{1}", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, {2}, {3}, {4}' -f $partName, $mesh, $sx, $sy, $sz))
    }
    $partCount++
}

if ($partCount -eq 0) { throw "rig '$Rig' has no MeshPart with a MeshId" }

# ---- decals --------------------------------------------------------------
$decalIds = New-Object System.Collections.Generic.List[string]
foreach ($d in $modelNode.SelectNodes(".//Item[@class='Decal' or @class='Texture']")) {
    $t = $d.SelectSingleNode("./Properties/Content[@name='Texture']")
    if ($null -eq $t) { continue }
    $id = ($t.InnerText -replace '[^0-9]', '')
    if (-not [string]::IsNullOrWhiteSpace($id)) { $decalIds.Add($id) }
}

$decalLua = 'nil'
if (-not [string]::IsNullOrWhiteSpace($Decal)) {
    $pair = $Decal -split '=', 2
    $decalLua = ('{{ part = "{0}", texture = "rbxassetid://{1}" }}' -f $pair[0], ($pair[1] -replace '[^0-9]', ''))
}
elseif ($decalIds.Count -gt 0) {
    # prefer the head: a face decal belongs there, not on whatever came first
    $hostName = $null
    foreach ($r in $rows) {
        $candidate = $r.Split('"')[1]
        if ($candidate -match '^(Fake)?Head$') { $hostName = $candidate; break }
    }
    if (-not $hostName) { $hostName = $rows[0].Split('"')[1] }
    $decalLua = ('{{ part = "{0}", texture = "rbxassetid://{1}" }}' -f $hostName, $decalIds[0])
}

$rowsOut = $rows | ForEach-Object { $_ + ' },' }

$header = @"
--[[
	$Name.build.lua  -  generated by tools/rig-to-lua.ps1
	rig      : $Rig
	source   : $(Split-Path $File -Leaf)
	parts    : $partCount
	decal ids: $($decalIds -join ', ')
	Paste into the Studio command bar; the rig appears under Workspace.Monsters.$Name
--]]

local CONFIG = {
	folderName = "Monsters",
	modelName = "$Name",
	placeAt = Vector3.new($PlaceAt),
	anchored = true,
}

local PARTS = {
"@

$footer = @"
}

local DECAL = $decalLua

local Workspace = game:GetService("Workspace")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local sum, count = Vector3.zero, 0
for _, row in ipairs(PARTS) do
	if row[3] ~= nil then
		sum = sum + Vector3.new(row[3], row[4], row[5])
		count = count + 1
	end
end
local pivot = if count > 0 then sum / count else Vector3.zero

local folder = Workspace:FindFirstChild(CONFIG.folderName)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = CONFIG.folderName
	folder.Parent = Workspace
end

local old = folder:FindFirstChild(CONFIG.modelName)
if old then old:Destroy() end

local recording
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("Build " .. CONFIG.modelName)
end)

local model = Instance.new("Model")
model.Name = CONFIG.modelName

local byName = {}
for _, row in ipairs(PARTS) do
	local part = Instance.new("MeshPart")
	part.Name = row[1]
	part.MeshId = "rbxassetid://" .. row[2]
	part.Size = Vector3.new(row[15], row[16], row[17])
	part.Anchored = CONFIG.anchored
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true

	if row[3] ~= nil then
		local offset = Vector3.new(row[3], row[4], row[5]) - pivot + CONFIG.placeAt
		part.CFrame = CFrame.new(offset)
			* CFrame.new(0, 0, 0,
				row[6], row[7], row[8],
				row[9], row[10], row[11],
				row[12], row[13], row[14])
	else
		part.CFrame = CFrame.new(CONFIG.placeAt)
	end

	part.Parent = model
	byName[part.Name] = part
end

if DECAL and DECAL.texture then
	local host = byName[DECAL.part] or model:FindFirstChildWhichIsA("MeshPart")
	if host then
		local d = Instance.new("Decal")
		d.Name = CONFIG.modelName .. "Face"
		d.Face = Enum.NormalId.Front
		d.Texture = DECAL.texture
		d.Parent = host
	end
end

model.Parent = folder

if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
end

pcall(function() Selection:Set({ model }) end)
print(string.format("[%s] %d parts -> %s", CONFIG.modelName, #PARTS, model:GetFullName()))
"@

$lua = $header + "`r`n" + ($rowsOut -join "`r`n") + "`r`n" + $footer

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($Out, $lua, $utf8)

Write-Host ("rig '{0}': {1} parts, {2} decal id(s)" -f $Rig, $partCount, $decalIds.Count) -ForegroundColor Green
Write-Host ("written: {0}" -f $Out) -ForegroundColor Cyan
