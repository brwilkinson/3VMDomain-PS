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
     }
    @{ 
        NodeName = "DC2"
		Path = 'C:\DC2.txt'
     }
    @{ 
        NodeName = "MS1"
		Path = 'C:\MS1.txt'
     }
 )
} 