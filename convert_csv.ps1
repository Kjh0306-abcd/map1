# CSV to JS converter script
$csvPath = "소상공인시장진흥공단_상가(상권)정보_부산_편의점_202606.csv"
$outJsPath = "store_data.js"

$lines = [System.IO.File]::ReadAllLines($csvPath, [System.Text.Encoding]::UTF8)
if ($lines.Length -lt 2) {
    Write-Error "CSV file empty or not found"
    exit 1
}

# Parse header
$header = $lines[0] -split '","'
for ($i = 0; $i -lt $header.Length; $i++) {
    $header[$i] = $header[$i].Trim('"')
}

$idxId = [array]::IndexOf($header, "상가업소번호")
$idxName = [array]::IndexOf($header, "상호명")
$idxBranch = [array]::IndexOf($header, "지점명")
$idxGu = [array]::IndexOf($header, "시군구명")
$idxDong = [array]::IndexOf($header, "행정동명")
$idxRoad = [array]::IndexOf($header, "도로명주소")
$idxJibun = [array]::IndexOf($header, "지번주소")
$idxLng = [array]::IndexOf($header, "경도")
$idxLat = [array]::IndexOf($header, "위도")

function Determine-Brand($name) {
    if ($name -match 'GS25|지에스25|GS 25') { return 'GS25' }
    if ($name -match 'CU|씨유|C.U') { return 'CU' }
    if ($name -match '세븐일레븐|7-ELEVEN|7-eleven|7ELEVEN|세븐') { return '세븐일레븐' }
    if ($name -match '이마트24|emart24|E마트24|emart') { return '이마트24' }
    if ($name -match '미니스톱|ministop|MINISTOP') { return '미니스톱' }
    if ($name -match '씨스페이스|c-space|C-SPACE') { return '씨스페이스' }
    return '기타'
}

$stores = [System.Collections.Generic.List[PSObject]]::new()

for ($r = 1; $r -lt $lines.Length; $r++) {
    $line = $lines[$r].Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    
    # Custom CSV split handling quotes
    $tokens = [System.Text.RegularExpressions.Regex]::Split($line, '(?<=^|",)(?=")|(?<="),(?=")|(?<="),(?=$)')
    # If standard split by comma with quotes:
    $parts = [System.Collections.Generic.List[string]]::new()
    $inQuotes = $false
    $cur = [System.Text.StringBuilder]::new()
    
    for ($c = 0; $c -lt $line.Length; $c++) {
        $ch = $line[$c]
        if ($ch -eq '"') {
            $inQuotes = -not $inQuotes
        } elseif ($ch -eq ',' -and -not $inQuotes) {
            $parts.Add($cur.ToString().Trim('"'))
            $cur.Clear() | Out-Null
        } else {
            $cur.Append($ch) | Out-Null
        }
    }
    $parts.Add($cur.ToString().Trim('"'))
    
    if ($parts.Count -le [Math]::Max($idxLng, $idxLat)) { continue }
    
    $latStr = $parts[$idxLat]
    $lngStr = $parts[$idxLng]
    
    [double]$lat = 0
    [double]$lng = 0
    
    if (-not [double]::TryParse($latStr, [ref]$lat) -or -not [double]::TryParse($lngStr, [ref]$lng)) {
        continue
    }
    
    # Check valid coordinate range for Busan (Lat: 34.8 ~ 35.5, Lng: 128.7 ~ 129.4)
    if ($lat -lt 34.5 -or $lat -gt 36.0 -or $lng -lt 128.0 -or $lng -gt 130.0) {
        continue
    }
    
    $name = $parts[$idxName]
    $branch = $parts[$idxBranch]
    $brand = Determine-Brand $name
    $gu = $parts[$idxGu]
    $dong = $parts[$idxDong]
    $road = $parts[$idxRoad]
    $jibun = $parts[$idxJibun]
    $id = $parts[$idxId]
    
    $storeObj = [PSCustomObject]@{
        id = $id
        name = $name
        branch = $branch
        brand = $brand
        gu = $gu
        dong = $dong
        road = $road
        jibun = $jibun
        lat = [Math]::Round($lat, 6)
        lng = [Math]::Round($lng, 6)
    }
    $stores.Add($storeObj)
}

$json = $stores | ConvertTo-Json -Compress
$finalJs = "// 부산시 편의점 상권 데이터 (자동 생성)`nconst STORE_DATA = " + $json + ";"
[System.IO.File]::WriteAllText($outJsPath, $finalJs, [System.Text.Encoding]::UTF8)

Write-Output "Successfully generated $outJsPath with $($stores.Count) stores."
