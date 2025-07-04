# NetTrace Module - Network Traffic Generator
# Version: 1.1.0
# Author: Naveed Khan
# Company: Hogwarts

# This script generates network traffic to test NetTrace functionality

Write-Output "NetTrace Module - Network Traffic Generator"
Write-Output "Version: 1.1.0"
Write-Output "Author: Naveed Khan"
Write-Output "Company: Hogwarts"
Write-Output ""

Write-Output "This script generates network traffic for testing NetTrace."
Write-Output "It will make HTTP requests to various websites to create"
Write-Output "network activity that can be captured by NetTrace."
Write-Output ""

# Configuration
$Websites = @(
    "https://www.google.com",
    "https://www.microsoft.com",
    "https://www.github.com",
    "https://www.stackoverflow.com",
    "https://www.wikipedia.org"
)

$RequestCount = 50
$DelayBetweenRequests = 1  # seconds

Write-Output "Configuration:"
Write-Output "  Websites: $($Websites.Count) sites"
Write-Output "  Requests per site: $RequestCount"
Write-Output "  Delay between requests: $DelayBetweenRequests seconds"
Write-Output "  Total requests: $($Websites.Count * $RequestCount)"
Write-Output ""

$confirm = Read-Host "Start generating network traffic? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Output "Network traffic generation cancelled."
    exit 0
}

Write-Output "Starting network traffic generation..."
Write-Output ""

$totalRequests = 0
$successfulRequests = 0
$failedRequests = 0

# Generate traffic for each website
foreach ($website in $Websites) {
    Write-Output "Generating traffic for: $website"

    # Create background jobs for parallel requests
    $jobs = @()
    for ($i = 1; $i -le $RequestCount; $i++) {
        $job = Start-Job -ScriptBlock {
            param($url)
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                return @{
                    Success = $true
                    StatusCode = $response.StatusCode
                    ContentLength = $response.Content.Length
                }
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $website

        $jobs += $job
        $totalRequests++

        # Small delay between job starts
        Start-Sleep -Milliseconds 100
    }

    # Wait for all jobs to complete and collect results
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    # Count successful and failed requests
    $siteSuccessful = ($results | Where-Object { $_.Success }).Count
    $siteFailed = ($results | Where-Object { -not $_.Success }).Count

    $successfulRequests += $siteSuccessful
    $failedRequests += $siteFailed

    Write-Output "  Completed: $siteSuccessful successful, $siteFailed failed"

    # Delay before next website
    Start-Sleep -Seconds $DelayBetweenRequests
}

Write-Output ""
Write-Output "Network traffic generation completed!"
Write-Output ""
Write-Output "Summary:"
Write-Output "  Total requests: $totalRequests"
Write-Output "  Successful: $successfulRequests"
Write-Output "  Failed: $failedRequests"
Write-Output "  Success rate: $([math]::Round(($successfulRequests / $totalRequests) * 100, 2))%"
Write-Output ""
Write-Output "This network activity should now be visible in your NetTrace capture."
Write-Output "Check your trace files for the generated network traffic." 