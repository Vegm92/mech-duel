$G = "C:\Users\victo\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$R = Split-Path $PSScriptRoot
$P = "$R\godot"
$V = (Select-String -Path "$P\project.godot" -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
$B = "$R\build"
$D = "$B\MechDuel-v$V-windows"

foreach ($t in "sim_rules_test", "garage_parts_test", "sound_test", "hype_test", "killcam_test", "progress_test", "radial_test", "difficulty_test") {
	& $G --headless --path $P -s "res://tests/$t.gd" 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "$t failed" }
}

Remove-Item -Recurse -Force $D, "$D.zip" -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$D\licenses" | Out-Null
& $G --headless --path $P --export-release "Windows Desktop" "$D\MechDuel.exe"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$D\MechDuel.exe")) { throw "export failed" }
& $G --headless --path $P -s "$R\tools\godot_licenses.gd" -- "$D\licenses\GODOT.txt" | Out-Null
Copy-Item "$R\CREDITS.txt" $D
Copy-Item "$P\assets\fonts\saira\OFL.txt" "$D\licenses\OFL-Saira.txt"
Copy-Item "$P\assets\fonts\exo2\OFL.txt" "$D\licenses\OFL-Exo2.txt"
Copy-Item "$P\assets\sounds\LICENSE.txt" "$D\licenses\SOUNDS.txt"
Compress-Archive -Path "$D\*" -DestinationPath "$D.zip"
Get-FileHash "$D.zip" -Algorithm SHA256 | Format-List Path, Hash
