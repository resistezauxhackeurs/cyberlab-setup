$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\common\base.ps1")
Assert-Administrator
Write-Log "Début du provisioning Windows Client."
# TODO : ajouter les outils et configurations du poste client.
Write-Log "Squelette Windows Client terminé : aucune modification logicielle effectuée."
