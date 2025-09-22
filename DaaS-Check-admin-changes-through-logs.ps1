<#  
##########################################################################################################################################
.TITLE          :   DaaS-Check-admin-changes-through-logs.ps1

.FUNCTION       :   Check logs for any update in admin accounts in the lastr 30 days - Citrix Cloud through REST API

.PARAMETERS     :    
             		mandatory: 
                        secretPath        : secret API using SPN to logon to cloud. csv file in this format: customerId,citrixAPIKey,secretKey
                        non mandatory
                        region            : Citrix Cloud region to contact: eu, us or ap are supported, default is set to eu


.EXAMPLE        :
                        .\DaaS-Check-admin-changes-through-logs.ps1 -secretPath 'C:\SecureClients\Servicee_principalFull.csv' -region 'eu'
   
   

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 1.0

.HISTORY       :    

#> 



param(
    [Parameter(Mandatory = $false)] [string]$secretPath, # csv file in this format: customerId,citrixAPIKey,secretKey. 
    [Parameter(Mandatory = $false)] [string]$region='eu' # eu, us or ap are supported, default is eu
)

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'                
#-----------------------------
#   Script prerequisites
#-----------------------------
        $ErrorActionPreference = "Stop"
        $Scriptpath = Split-Path $MyInvocation.MyCommand.Path
        #initialize secretPath
                if (-NOT $PSBoundParameters.ContainsKey('secretPath')){
                        [string] $secretPath = "$($Scriptpath)\secret.csv"
                }

    #initialize region
        if (-NOT $PSBoundParameters.ContainsKey('region')){
                $region='eu'
        }
        switch ($region){
            'us' {$tokenUrl = "https://api-us.cloud.com/cctrustoauth2/root/tokens/clients"}
            'eu' {$tokenUrl = "https://api-eu.cloud.com/cctrustoauth2/root/tokens/clients"}
            'ap' {$tokenUrl = "https://api-ap-s.cloud.com/cctrustoauth2/root/tokens/clients"}
        }
        
    #importing secrets: 
        $secret = Import-Csv $secretPath -Delimiter ','
        $customerId = $secret.customerId    
        $clientId = $secret.citrixAPIKey
        $clientSecret = $secret.secretKEY

# get the bearer token
        try{

                $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
                    grant_type    = "client_credentials"
                    client_id	  = $clientId
                    client_secret = $clientSecret
                }
                $token = ($response.Content | ConvertFrom-Json).access_token
                write-host "bearer token retrieved" -ForegroundColor Green
        } 
        catch{
                write-host "Error retrieving bearer token" -ForegroundColor Red
        }
# Create the header  
        $headers = @{
                Authorization = "CwsAuth Bearer=$($token)";
                'Citrix-CustomerId' = $customerId;
                'Accept'="application/json"
                'Content-Type'="application/json"
        }

#system logs

        $startDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ") #last 30 days
        $myurl = "https://api-us.cloud.com/systemlog/records?StartDateTime="+$startDate
        $response = Invoke-RestMethod -Uri $myUrL -Method GET -Headers $headers 
        $continuationtoken = $response.continuationToken
        $result=$response.items
        while ($null -ne $ContinuationToken){
                    $requestUriContinue = $myUrL + "&ContinuationToken=" + $ContinuationToken
                    $responsePage = Invoke-RestMethod -Uri $requestUriContinue -Method GET -Headers $headers
                    $result += $responsePage.Items
                    $ContinuationToken = $responsePage.ContinuationToken
        }

        $result |Where-Object {$_.eventtype -eq 'Platform/administrator/update'} |Select-Object utctimestamp,targetdisplayname,targetemail, beforechanges,afterchanges |out-gridview -Title 'system logs - admin updates only'