$G = "C:\Users\victo\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
$R = Split-Path $PSScriptRoot
$P = "$R\godot"
$V = (Select-String -Path "$P\project.godot" -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
$B = "$R\build"

foreach ($t in "sim_rules_test", "garage_parts_test", "sound_test", "hype_test", "killcam_test", "progress_test", "radial_test", "difficulty_test", "siege_rules_test", "siege_bots_test", "siege_arena_test") {
	& $G --headless --path $P -s "res://tests/$t.gd" 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "$t failed" }
}

foreach ($v in @(@{ Preset = "Windows Desktop"; Name = "MechDuel-v$V-windows" })) {
	$D = "$B\$($v.Name)"
	New-Item -ItemType Directory -Force "$D\licenses" | Out-Null
	& $G --headless --path $P --export-release $v.Preset "$D\MechDuel.exe" 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$D\MechDuel.exe")) { throw "export failed: $($v.Preset)" }
	& $G --headless --path $P -s "$R\tools\godot_licenses.gd" -- "$D\licenses\GODOT.txt" 2>&1 | Out-Null
	Copy-Item "$R\CREDITS.txt" $D -Force
	Copy-Item "$P\assets\fonts\saira\OFL.txt" "$D\licenses\OFL-Saira.txt" -Force
	Copy-Item "$P\assets\fonts\exo2\OFL.txt" "$D\licenses\OFL-Exo2.txt" -Force
	Copy-Item "$P\assets\sounds\LICENSE.txt" "$D\licenses\SOUNDS.txt" -Force
	Compress-Archive -Path "$D\*" -DestinationPath "$D.zip" -Force
	Get-FileHash "$D.zip" -Algorithm SHA256 | Format-List Path, Hash
}
