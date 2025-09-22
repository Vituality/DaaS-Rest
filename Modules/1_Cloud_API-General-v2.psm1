function Get-BearerToken{
    Param(
        [Parameter(Mandatory = $true)] [string]$clientid,
        [Parameter(Mandatory = $true)] [String]$clientsecret,
        [Parameter(Mandatory = $false)] [String]$region='eu'
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
        switch ($region)
                {
                'us' {$tokenUrl = "https://api-us.cloud.com/cctrustoauth2/root/tokens/clients"}
                'eu' {$tokenUrl = "https://api-eu.cloud.com/cctrustoauth2/root/tokens/clients"}
                'ap' {$tokenUrl = "https://api-ap-s.cloud.com/cctrustoauth2/root/tokens/clients"}
                }
        $response = Invoke-WebRequest $tokenUrl -Method POST -Body @{
	        grant_type    = "client_credentials"
	        client_id	  = $clientid
	        client_secret = $clientsecret
        }
        $token = ($response.Content | ConvertFrom-Json).access_token
        return @{Level='Success';Message=" $($MyInvocation.MyCommand.Name):Success : Bearer token found for customer";Data=$token}
    } 
	catch 
	{
		return @{Level='Error';Message=" $($MyInvocation.MyCommand.Name):Error : unable to retrive the Bearer Token for customer $($hostingConnectionName)";Data=''}
	}
}

function Invoke-CloudRequest{
    Param(
    [Parameter(Mandatory = $true)] [String]$myURL,
    [Parameter(Mandatory = $true)] $headers,
    [Parameter(Mandatory = $false)] $parameters
    )
    $allresults =@()
    try{
        write-host "Retrieving Data ."

        if (-NOT $PSBoundParameters.ContainsKey('parameters')){
            $result = (Invoke-RestMethod -Method Get -Uri $myURL -Headers $headers)
            $allresults = ($result.items)
            while ($null -ne $result.continuationToken){ #if the continuation Token is not null, it means that we have more results to get
                $result = (Invoke-RestMethod -Method Get -Uri ($myurl+"?continuationToken="+$result.continuationtoken)  -Headers $headers) #get the next results
                $newresult = ($result.items)
                $allresults = @($allresults)+@($newresult)
            }
        }
        else{
            $result = $result = (Invoke-RestMethod -Method Get -Uri $myURL -Headers $headers -Body $parameters)
            $odataNextLink=((($result.RawContent -split '"@odata.nextLink":"')[1]) -split '"}')[0]
            $allresults = ($result.items)
            while ($null -ne $result.continuationToken){ #if the continuation Token is not null, it means that we have more results to get
                $result = (Invoke-RestMethod -Method Get -Uri ($myurl+"?continuationToken="+$result.continuationtoken)  -Headers $headers -body $parameters) #get the next results
                $newresult = ($result.items)
                $allresults = @($allresults)+@($newresult)
            }
            while ($odataNextLink -ne ''){
                $result = (Invoke-RestMethod -Method Get -Uri $odataNextLink -Headers $headers -body $parameters) #get the next results
                $odataNextLink=((($result.RawContent -split '"@odata.nextLink":"')[1]) -split '"}')[0]
                $newresult = ($result.items)
                $allresults = @($allresults)+@($newresult)
            }
      }
        return @{Level='Success';Message=" $($MyInvocation.MyCommand.Name):Success : data found";Data=$allresults}
    }
    catch{
        return @{Level='Error';Message=" $($MyInvocation.MyCommand.Name):Error : unable to retrieve Data";Data=''}
    }
} 




