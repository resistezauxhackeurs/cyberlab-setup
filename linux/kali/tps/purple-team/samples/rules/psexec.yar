/*
 * Chemin : tps/purple-team/samples/rules/psexec.yar
 * Fil rouge Purple Team - Active Directory
 * Cible : PsExec.exe et PsExec64.exe (dossier samples/)
 *
 * Note pont purple team : la chaine PSEXESVC est le nom du service depose
 * sur la cible => meme IOC que la regle Sigma f2a4b8c1-latmov-0013 (\PSEXESVC.exe).
 */

rule SysinternalsTool_PsExec
{
    meta:
        description = "PsExec (Sysinternals) - execution distante, detourne pour le mouvement lateral"
        author      = "Resistez aux hackeurs - fil rouge Purple Team"
        reference   = "https://attack.mitre.org/software/S0029/"
        sample      = "PsExec.exe / PsExec64.exe"
        date        = "2026-10-20"
    strings:
        $n1  = "PsExec" ascii wide nocase
        $n2  = "Execute processes remotely" ascii wide nocase
        $n3  = "Sysinternals" ascii wide nocase
        $svc = "PSEXESVC" ascii wide            // service depose sur la cible = IOC cle
        $ms  = "Mark Russinovich" ascii wide
    condition:
        uint16(0) == 0x5A4D and 2 of them
}
