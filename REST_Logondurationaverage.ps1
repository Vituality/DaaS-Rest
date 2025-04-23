<#  
##########################################################################################################################################
.TITLE          :   Cloud_API-v1.0 logon duration average

.FUNCTION       :   Create an Inventory of Customers Workspace Apps

.PARAMETERS     :    
             		mandatory: 
                        client_id         : ID for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        client_secret     : Client Secret for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        customer_id       : Customer ID for Citrix cloud API access - see "Get started with Citrix cloud API" https://developer.cloud.com/explore-more-apis-and-sdk/cloud-services-platform/citrix-cloud-api-overview/docs/get-started-with-citrix-cloud-apis
                        Date              : collect only failures detected after this date 
                        Region            : Citrix cloud Region: could be: us, eu or ap (choose the closest one to the machine used that runs the script)

.REQUIEREMENTS  :     Access to Citrix Cloud over the Internet


.EXAMPLE        :
 
   .\Cloud_API-v1.3-WorkspaceAppInventory.ps1 -client_id '##################' -client_secret '###############' -customer_id '##########' -date '2022-01-01' -region 'eu'
   
.AUTHOR        :     Vincent Rombau - Solution Delivery Architect - Citrix Consulting
                     Vincent.Rombau@Citrix.com

.VERSION       : 	 1.3

.HISTORY       :    2021-09-06: Version 0.1 - Initial version created.
                    2021-09-08: Version 1.0 - ready to share
                    2021-09-09: veriosn 1.1 - optimized the requests and added a progress bar
                    2021-10-13: version 1.2 - added retry in case of a web error
                    2022-02-01: version 1.3 - specific version for Workspace App Inventory
#> 

#Read the parameters passed from command line
Param(
    
    [string]$client_id='0e3b9a89-8fe3-43e2-acdf-49d27c556627',
    
	[string]$client_secret='O96pDtu4SfxqbTgi7rdrIw==',
    
	[string]$customer_id='dcint4b1816a',
    
	[string]$date='2020-01-01',
    
	[string]$region='eu'

)

	$ErrorActionPreference = "Stop"

    <#
    The web server we are connecting to may not have a trusted security certificate on the host running the PowerShell script. We need to change the certificate policy to prevent errors. 
    REST API requires TLS 1.2, which isn�t enabled by default in PowerShell 5 and below. 
    #>


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


# get the bearer token

try 
	{
        $tokenUrl = 'https://api-us.cloud.com/cctrustoauth2/root/tokens/clients'
        $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
	        grant_type    = "client_credentials"
	        client_id	  = $client_id
	        client_secret = $client_secret
        }
        $token = ($response.Content | ConvertFrom-Json).access_token
    } 
	catch 
	{
		return "An error occurred."
	}


# Create the headers  
    $headers = @{
	    Authorization = "CwsAuth Bearer=$($token)"
	    'Citrix-CustomerId' = $customer_id;
    }
    
# requesting connection failures, define parameters and URL
    $Parameters = @{
             
              '$apply' = 'filter((CreatedDate gt 2021-01-01) and ((User/FullName) ne null))/groupby((User/FullName),aggregate (LogonDuration with average as AvgLogonDuration, CreatedDate with countdistinct as AmountOfSessions))'
              '$orderby'='AmountOfSessions desc'
              '$count' = 'true'
            }
    
    switch ($region)
    {
    'us' {$myurl = "https://api-us.cloud.com/monitorodata/sessions"}
    'eu' {$myurl = "https://api-eu.cloud.com/monitorodata/sessions"}
    'ap' {$myurl = "https://api-ap-s.cloud.com/monitorodata/sessions"}
    }
    
    $allresults =@()
#request first 100 results
    write-host "Retrieving Data ."
    $results = ((Invoke-WebRequest $myurl -Headers $headers -Body $Parameters)  | ConvertFrom-Json )
    $allresults = $results.value
    $length = $results.'@odata.count'

    write-host 'Discovered' $length 'different workspace app versions since'$date

#request other results if more than 100 exists
 while($results.'@odata.nextLink' -ne $null)
    {
        $count +=100
        $tries = 0
        while ($tries -lt 10) {  #the result may fail if the server is too busy, this loop allows to retry 10 times in case of failure
            try{
                $results = Invoke-RestMethod $results.'@odata.nextLink' -Headers $headers
                $tries = 11;
                } catch {$tries ++} 
            }  
        $allresults += $results.value 
        $percent = [math]::round($count*100/$length)
        try{write-progress -activity "Data gathering in progress.         " -status "$percent% complete" -percentcomplete $percent} catch{}
    }
   
$allresults  |out-gridview
$allresults  |Export-Csv c:\temp\logonavegare.csv