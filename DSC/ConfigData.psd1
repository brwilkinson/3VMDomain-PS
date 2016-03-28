#
# ConfigData.psd1
#

@{ 
AllNodes = @( 
    @{ 
        NodeName = "*" 
        PSDscAllowPlainTextPassword = $true
		PSDscAllowDomainUser = $true
     } 
    @{ 
        NodeName = "DC1"
		Path = 'C:\DC1.txt'
		Role = 'PDC'
     }
    @{ 
        NodeName = "DC2"
		Path = 'C:\DC2.txt'
		Role = 'DC'
     }
    @{ 
        NodeName = "MS1"
		Path = 'C:\MS1.txt'
		Role = 'MemberServer'
     }
 )
} 