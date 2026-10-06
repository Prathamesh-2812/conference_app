$filePath = "d:\conference_app\flutter_app\lib\main.dart"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

$content = $content.Replace("base64Image = 'data:image/jpeg;base64,$';", 'base64Image = ''data:image/jpeg;base64,'' + base64Encode(bytes);')
$content = $content.Replace("content: Text('AI Face Recognition found $ photos of you!'),", 'content: Text(''AI Face Recognition found '' + matched.length.toString() + '' photos of you!''),')
$content = $content.Replace("'Your Matched Photos ($)'", '''Your Matched Photos ('' + _matchedPhotos.length.toString() + '')''')

[System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
Write-Host "Fixed string interpolations successfully!"
