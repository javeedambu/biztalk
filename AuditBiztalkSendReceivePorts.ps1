# ===========================
# BizTalk Port Export Script (Enhanced)
# Exports Send & Receive Ports with filters, handlers, pipelines, etc.
# ===========================

# Load BizTalk ExplorerOM
[void][Reflection.Assembly]::LoadWithPartialName("Microsoft.BizTalk.ExplorerOM")

# Connect to BizTalkMgmtDb
$catalog = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
$catalog.ConnectionString = "SERVER=SQLSERVERNAME;DATABASE=BizTalkMgmtDb;Integrated Security=SSPI"

# Function: Parse Send Port Filters from Filter XML
function Get-SendPortFilter {
    param (
        [string]$filterXml
    )

    if ([string]::IsNullOrWhiteSpace($filterXml)) {
        return "-"
    }

    try {
        $xml = [xml]$filterXml
        $filters = @()

        foreach ($stmt in $xml.Filter.Group.Statement) {
            $property = $stmt.Property
            $operator = switch ($stmt.Operator) {
                "0" { "==" }
                "1" { "!=" }
                "2" { "<" }
                "3" { "<=" }
                "4" { ">" }
                "5" { ">=" }
                default { "??" }
            }
            $value = $stmt.Value
            $filters += "$property $operator '$value'"
        }

        return ($filters -join " AND ")
    } catch {
        return "[Invalid filter XML]"
    }
}

# Collect all ports
$ports = @()

# Receive Ports
foreach ($rp in $catalog.ReceivePorts) {
    $appName = $rp.Application.Name
    $isTwoWay = $rp.IsTwoWay

    foreach ($rl in $rp.ReceiveLocations) {
        $ports += [PSCustomObject]@{
            Type              = "Receive"
            ApplicationName   = $appName
            PortName          = $rp.Name
            LocationName      = $rl.Name
            URI               = $rl.Address
            TransportType     = $rl.TransportType.Name
            Enabled           = $rl.Enabled
            Filter            = "-"
            ReceivePipeline   = $rl.ReceivePipeline.FullName
            SendPipeline      = "-"
            IsTwoWay          = $isTwoWay
            OrderedDelivery   = "-"
            DeliveryNotify    = "-"
            SendHandler       = "-"
            ReceiveHandler    = $rl.ReceiveHandler.Name
            RetryCount        = "-"
            RetryInterval     = "-"
        }
    }
}

# Send Ports
foreach ($sp in $catalog.SendPorts) {
    $appName     = $sp.Application.Name
    $filterStr   = Get-SendPortFilter -filterXml $sp.Filter
    $primary     = $sp.PrimaryTransport

    $ports += [PSCustomObject]@{
        Type              = "Send"
        ApplicationName   = $appName
        PortName          = $sp.Name
        LocationName      = "-"
        URI               = $primary.Address
        TransportType     = $primary.TransportType.Name
        Enabled           = $sp.Status -eq "Started"
        Filter            = $filterStr
        ReceivePipeline   = "-"
        SendPipeline      = $sp.SendPipeline.FullName
        IsTwoWay          = $sp.IsTwoWay
        OrderedDelivery   = $sp.IsOrderedDelivery
        DeliveryNotify    = $sp.DeliveryNotification
        SendHandler       = $primary.SendHandler.Name
        ReceiveHandler    = "-"
        RetryCount        = $primary.RetryCount
        RetryInterval     = $primary.RetryInterval
    }
}

# Export to CSV
$timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$csvPath = "C:\BizTalk_Port_Export_Enhanced_$timestamp.csv"
$ports | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Output "✅ Export complete:"
Write-Output $csvPath
