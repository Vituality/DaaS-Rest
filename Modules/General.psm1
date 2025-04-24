function add-LogEntry {
    param (
        [Parameter(Mandatory = $true,ValueFromPipeline = $true)] [System.Array]$logEntry, 
        [Parameter(Mandatory = $true,ValueFromPipeline = $true)] [string]$logFile
    )
    [string] $log
    $logLevel = $logEntry.Level
    $logMessage = $logEntry.Message
    switch ($logLevel){
    "Error" {Write-Host "$logMessage}" -ForegroundColor Red; $log = "$($(Get-Date -Format "dd.MM.yyyy HH:mm:ss")) | [ERROR]: $logMessage"}
    "Warning" {Write-Host "$logMessage" -ForegroundColor Yellow; $log = "$($(Get-Date -Format "dd.MM.yyyy HH:mm:ss")) | [WARNING]: $logMessage"}
    "Information" {Write-Host "$logMessage" -ForegroundColor White; $log = "$($(Get-Date -Format "dd.MM.yyyy HH:mm:ss")) | [Information]: $logMessage"}
    "Success" {Write-Host "$logMessage" -ForegroundColor Green; $log = "$($(Get-Date -Format "dd.MM.yyyy HH:mm:ss")) | [SUCCESS]: $logMessage"}
    Default {Write-Host "$logMessage"; $log = "$logMessage"}
    }
    $log | Out-File $logFile -Append
}

Function Add-PowershellSnapin{
	param(
		[Parameter(Mandatory=$true)] $snapin
	)
	try	{
		$snapins = Get-PSSnapin | Where-Object { $_.Name -like $snapin }
		if ($null -eq $snapins){
                (Get-PSSnapin -Registered $snapin -ErrorAction stop) | Add-PSSnapin
                
            }
            return @{Level='Success';Message="$($MyInvocation.MyCommand.Name)  :Successfully added $snapin powershell snapins"}
	}
	catch{
		if ($_.exception.message -like "*An item with the same key has already been added*"){
            return @{Level='Information';Message="$($MyInvocation.MyCommand.Name): $($_.InvocationInfo.InvocationName): $($_.exception.message): $($snapin)"}
        }
        else{
            return @{Level='Error';Message="$($MyInvocation.MyCommand.Name):Error : $($_.InvocationInfo.InvocationName): $($_.exception.message)"}
        }
	}
}
Function Connect-DaaS{
	#Connect to Citrix DaaS platform
    param(
		[Parameter(Mandatory = $true)] [String]$customerId,
        [Parameter(Mandatory = $true)] [String]$citrixAPIKey,
        [Parameter(Mandatory = $true)] [String]$secretKEY,
		[Parameter(Mandatory = $true)] [String]$daaSProfile
    )
	try{
        # if a profile with the same name allready exist, the profile will be deleted
		if ((get-xdcredentials -listprofile |out-null) | Where-Object ProfileName -eq $daaSProfile){ 
			Clear-XDCredentials -ProfileName $daaSProfile |out-null
		}
        # create the connection profile
        set-XDCredentials -CustomerId $customerId -APIKey $citrixAPIKey -SecretKey $secretKEY -ProfileType CloudApi -StoreAs $daaSProfile |out-null
        #connect to the profile
		Get-XDAuthentication -ProfileName $daaSProfile |out-null
        #deleting the profile to enhance security
        Clear-XDCredentials -ProfileName $daaSProfile |out-null
        return @{Level='Success';Message="$($MyInvocation.MyCommand.Name) :Successfully connected to Citrix Cloud"}
    }
    catch {
        if ($_.exception.message -like "Invalid client id or secret") {
            return @{Level='Error';Message="$($MyInvocation.MyCommand.Name) :Get-XDAuthentication: Invalid client id or secret, Please check your Citrix Cloud secure client API access"}
        }
        else {
            return @{Level='Error';Message="$($MyInvocation.MyCommand.Name) :Error : $($_.InvocationInfo.InvocationName): $($_.exception.message)"}
        }
    }
}
Function Disconnect-DaaS{
    param(
    )
	#Disconnect from the Citrix DaaS platform
    try{
        $GLOBAL:XDSDKAuth  = 'OnPrem'
        set-XDCredentials -ProfileType OnPrem  |out-null
        #connect to the profile
		Get-XDAuthentication |out-null
        Clear-XDCredentials
        return @{Level='Success';Message="$($MyInvocation.MyCommand.Name) :Successfully disconnected from Citrix Cloud"}
    }
    catch{
        return @{Level='Error';Message="$($MyInvocation.MyCommand.Name):Error : $($_.InvocationInfo.InvocationName): $($_.exception.message)"}
    }   
}
Function Test-StringDoNotContainsCaracters{
    #ensure that identitypoll name is compliant: does not contains any of the caracters in referenz
    #referenz's format : @('\\','/',';',':','#','\.','\*','\?','\=','<','>','\|','\[','\]','\(','\)','\"',"'")
    
    param(
        [Parameter(Mandatory = $true)] [String]$string,
        [Parameter(Mandatory = $true)] [System.Array]$referenz
    )
    try{
        $referenzRegex = [string]::Join('|', $referenz)
        if ($string -notmatch $referenzRegex)   {return $true}
        else    {return $false}    
    }
    catch{
        return @{Level='Error';Message="$($MyInvocation.MyCommand.Name):Error : $($_.InvocationInfo.InvocationName): $($_.exception.message)"}
    }
}