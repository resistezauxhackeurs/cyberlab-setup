$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\common\base.ps1")
Assert-Administrator
Write-Log "Début du provisioning Windows Server."
# TODO : ajouter les fonctionnalités et outils nécessaires à tes TP.
# Préférer des installations versionnées et vérifier les codes de retour.
Write-Log "Squelette Windows Server terminé : aucune modification logicielle effectuée."
