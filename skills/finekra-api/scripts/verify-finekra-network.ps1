$server58 = Test-NetConnection -ComputerName 172.16.220.58 -Port 22
$elastic = Test-NetConnection -ComputerName 172.16.220.59 -Port 5601

[pscustomobject]@{
    server58 = [pscustomobject]@{
        host = "172.16.220.58"
        port = 22
        tcp = $server58.TcpTestSucceeded
        source = $server58.SourceAddress.IPAddress
    }
    elastic = [pscustomobject]@{
        host = "172.16.220.59"
        port = 5601
        tcp = $elastic.TcpTestSucceeded
        source = $elastic.SourceAddress.IPAddress
    }
} | ConvertTo-Json -Depth 5
