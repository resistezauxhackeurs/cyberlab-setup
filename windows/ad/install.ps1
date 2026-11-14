$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\common\base.ps1")
Assert-Administrator
Write-Log "Rôle Active Directory sélectionné."
Write-Warning "Aucune promotion AD automatique : renseigner d'abord domaine, DNS, IP et paramètres DSRM propres au TP."
# TODO : ajouter une étape interactive/paramétrée, puis installation AD DS et promotion.
