/*
 * Chemin : tps/purple-team/samples/rules/mimikatz.yar
 * Fil rouge Purple Team - Active Directory
 * Cible : le binaire compile 64 bits  samples/mimikatz.exe  (depot gentilkiwi)
 *
 * On detecte l'executable que l'attaquant lance reellement, pas la source.
 * La regle matche le mimikatz.exe 64 bits ET 32 bits (memes chaines) ; le
 * script validate-yara.sh cible le 64 bits via le chemin x64/.
 */

rule HackTool_Mimikatz
{
    meta:
        description = "Mimikatz - extraction de credentials (binaire compile, attaque 5)"
        author      = "Resistez aux hackeurs - fil rouge Purple Team"
        reference   = "https://github.com/gentilkiwi/mimikatz"
        sample      = "mimikatz.exe (64 bits)"
        date        = "2026-10-20"
        tlp         = "WHITE"
    strings:
        // commandes internes (presentes en clair dans le binaire, souvent en UTF-16)
        $cmd1 = "sekurlsa::logonpasswords" ascii wide
        $cmd2 = "privilege::debug"         ascii wide
        $cmd3 = "lsadump::dcsync"          ascii wide
        $cmd4 = "sekurlsa::"               ascii wide
        // signatures auteur / produit
        $sig1 = "gentilkiwi"               ascii wide
        $sig2 = "mimikatz"                 ascii wide nocase
        $sig3 = "Benjamin DELPY"           ascii wide
        // morceau de la banniere ASCII caracteristique
        $ban  = "## \\ / ##"               ascii
    condition:
        uint16(0) == 0x5A4D       // en-tete PE "MZ" : on vise un executable
        and 2 of them             // 2 motifs discriminants suffisent
}
