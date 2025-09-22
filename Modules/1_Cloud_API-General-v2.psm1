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
    [Parameter(Mandatory = $true)] $headers
    )
    try{
        write-host "Retrieving Data ."
            $response = Invoke-RestMethod -Uri $myUrL -Method GET -Headers $headers 
            [string]$continuationtoken = $response.continuationToken
            $result=$response
            while (![string]::IsNullOrWhiteSpace($continuationtoken) ){
                        $requestUriContinue = $myUrL + "?ContinuationToken=" + $ContinuationToken
                        $responsePage = Invoke-RestMethod -Uri $requestUriContinue -Method GET -Headers $headers
                        $result.items += $responsePage.items
                        $ContinuationToken = $responsePage.ContinuationToken
            }
        return @{Level='Success';Message=" $($MyInvocation.MyCommand.Name):Success : data found";Data=$result}
    }
    catch{
        return @{Level='Error';Message=" $($MyInvocation.MyCommand.Name):Error : unable to retrieve Data";Data=''}
    }
} 


function Invoke-Odata{
    Param(
    [Parameter(Mandatory = $true)] [String]$myURL,
    [Parameter(Mandatory = $true)] $headers,
    [Parameter(Mandatory = $true)] $parameters
    )
    $allresults =@()
    try{
        write-host "Retrieving Data ."

            $result = (Invoke-WebRequest $myURL -Headers $headers -Body $parameters)
            $continuation_token=((($result.RawContent -split '"continuationToken":"')[1]) -split '"}')[0] # extract the Continuation Token from result
            $odataNextLink=((($result.RawContent -split '"@odata.nextLink":"')[1]) -split '"}')[0]
            $allresults = ($result | ConvertFrom-Json)
            while ($continuation_token -ne ''){ #if the continuation Token is not null, it means that we have more results to get
                $result = (Invoke-WebRequest ($myurl+'?continuationToken='+$continuation_token)  -Headers $headers -Body $parameters) #get the next results
                $continuation_token=((($result.RawContent -split '"continuationToken":"')[1]) -split '"}')[0] 
                $newresult = ($result | ConvertFrom-Json)
                $allresults = @($allresults)+@($newresult)
            }
            while ($odataNextLink -ne ''){
                $result = (Invoke-WebRequest $odataNextLink -Headers $headers) #get the next results
                $odataNextLink=((($result.RawContent -split '"@odata.nextLink":"')[1]) -split '"}')[0]
                $newresult = ($result | ConvertFrom-Json)
                $allresults = @($allresults)+@($newresult)
            
      }
        return @{Level='Success';Message=" $($MyInvocation.MyCommand.Name):Success : data found";Data=$allresults}
    }
    catch{
        return @{Level='Error';Message=" $($MyInvocation.MyCommand.Name):Error : unable to retrieve Data";Data=''}
    }
} 


