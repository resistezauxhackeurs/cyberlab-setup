/*
 * Chemin : tps/purple-team/samples/rules/advanced_ip_scanner.yar
 * Fil rouge Purple Team - Active Directory
 * Cible : Advanced_IP_Scanner_2.5.4594.1.exe (dossier samples/)
 */

rule APT_Tool_AdvancedIPScanner
{
    meta:
        description = "Advanced IP Scanner - scanner reseau detourne par les groupes ransomware"
        author      = "Resistez aux hackeurs - fil rouge Purple Team"
        reference   = "https://attack.mitre.org/software/S0552/"
        sample      = "Advanced_IP_Scanner_2.5.4594.1.exe"
        date        = "2026-10-20"
        tlp         = "WHITE"
    strings:
        $name1  = "Advanced IP Scanner" ascii wide nocase
        $name2  = "advanced_ip_scanner" ascii wide nocase
        $vendor = "Famatech" ascii wide nocase
        $pdb    = "advanced_ip_scanner.pdb" ascii nocase
        $url    = "advanced-ip-scanner.com" ascii wide nocase
    condition:
        uint16(0) == 0x5A4D          // en-tete PE "MZ"
        and 2 of them                // 2 motifs discriminants suffisent
}
