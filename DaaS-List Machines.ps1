<#  
##########################################################################################################################################
.TITLE          :   DaaS list machines

.FUNCTION       :   Querry Citrix DaaS and return machines through REST

.PARAMETERS     :    
             		mandatory: 
                        secretPath  :  csv file in this format: customerId,citrixAPIKey,secretKey. If this is not present, user will have to logon explicitely
                not mandatory
                        region      : eu, us or ap are supported, default is eu


.REQUIEREMENTS  :     
                    Access to Citrix Cloud over the Internet
                    #Read the parameters passed from command line
                    
.EXAMPLE        :
                    

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 0.

.HISTORY       :    

#> 



<#param(
    [Parameter(Mandatory = $false)] [string]$secretPath, # csv file in this format: customerId,citrixAPIKey,secretKey. If this is not present, user will have to logon explicitely
    [Parameter(Mandatory = $false)] [string]$region='eu' # eu, us or ap are supported, default is eu
)
 #>

$region='eu'
#-----------------------------
#   Script prerequisites
#-----------------------------
                $ErrorActionPreference = "Stop"
                $Scriptpath = Split-Path $MyInvocation.MyCommand.Path
                $ScriptName = $MyInvocation.MyCommand.Name
                
                # Create log file
                        $logDir = $Scriptpath+'\Logs'
                        if ((test-path $logDir) -ne "True") {$null = New-Item $Scriptpath\Logs -Type Directory}
                        $logFile  =  Join-Path $logDir ("$($ScriptName)_$(get-date -format yyyy-MM-dd-hh-mm).log")
                       
                # Import Modules
                        try{
                                Import-Module $Scriptpath\Modules\1_cloud_API-General.psm1 -Force
                                Import-Module $Scriptpath\Modules\General.psm1 -Force
                        }
                        catch{
                                Write-host "Error, cannot import Modules or start logging" -ForegroundColor Red 
                        Exit
                        }
                #initialize secretPath
                        if (-NOT $PSBoundParameters.ContainsKey('secretPath')){
                                [string] $secretPath = "$($Scriptpath)\secret.csv"
                        }

        #initialize region
        if (-NOT $PSBoundParameters.ContainsKey('region')){
                $region='eu'
        }
        
#importing secrets: 
        $secret = Import-Csv $secretPath -Delimiter ','
        $customerId = $secret.customerId    
        $clientId = $secret.citrixAPIKey
        $clientSecret = $secret.secretKEY

#Get the Bearer Token
        $token = Get-BearerToken -client_id $clientId -client_secret $clientSecret -region $region
        #add the log entry to the log file
        add-LogEntry -logEntry $token -logfile $logFile
# Create the header  
        $headers = @{
                Authorization = "CwsAuth Bearer=$($token.data)";
                'Citrix-CustomerId' = $customerId;
                'Accept'="application/json"
        }

#get DaaS Site
        $myURL = 'https://api.cloud.com/cvad/manage/me'
        $result=Invoke-CloudRequest -myURL $myURL -headers $headers
        #add the log entry to the log file
        add-LogEntry -logEntry $result -logfile $logFile
        $siteID = $result.data.Customers.sites.Id

$headers = @{
                Authorization = "CwsAuth Bearer=$($token.data)";
                'Citrix-CustomerId' = $customerId;
                'Citrix-InstanceId' = $siteID;        
                'Accept'="application/json"
        }


$myURL = 'https://api.cloud.com/cvad/manage/Machines'
$Machines=(Invoke-CloudRequest -myURL $myURL -headers $headers).data.items


