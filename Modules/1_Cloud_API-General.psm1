function Get-BearerToken{
    Param(
        [Parameter(Mandatory = $true)] [string]$client_id,
        [Parameter(Mandatory = $true)] [String]$client_secret,
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
	        client_id	  = $client_id
	        client_secret = $client_secret
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
    [Parameter(Mandatory = $true)] $header,
    [Parameter(Mandatory = $false)] [String]$parameters
    )
    try{
        write-host "Retrieving Data ."
        if (-NOT $PSBoundParameters.ContainsKey('parameters')){
            $results = ((Invoke-WebRequest $myURL -Headers $header)  | ConvertFrom-Json )
        }
        else{
            $results = ((Invoke-WebRequest $myURL -Headers $header -Body $parameters)  | ConvertFrom-Json )
        }
        return @{Level='Success';Message=" $($MyInvocation.MyCommand.Name):Success : data found";Data=$results}
    }
    catch{
        return @{Level='Error';Message=" $($MyInvocation.MyCommand.Name):Error : unable to retrieve Data";Data=''}
    }
} 




