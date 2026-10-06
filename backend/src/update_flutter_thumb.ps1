$filePath = "d:\conference_app\flutter_app\lib\main.dart"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

# In AI Selfie Tab grid
$oldGridImg1 = @"
              final item = _matchedPhotos[index];
              final url = resolveMediaUrl(item['url']);
              final caption = item['caption'] ?? 'Conference moment';
"@

$newGridImg1 = @"
              final item = _matchedPhotos[index];
              final thumbUrl = resolveMediaUrl(item['thumbnail_url'] ?? item['url']);
              final fullUrl = resolveMediaUrl(item['url']);
              final caption = item['caption'] ?? 'Conference moment';
"@

$content = $content.Replace($oldGridImg1, $newGridImg1)
$content = $content.Replace("final url = resolveMediaUrl(item['thumbnail_url'] ?? item['url']);", "final thumbUrl = resolveMediaUrl(item['thumbnail_url'] ?? item['url']);`n              final fullUrl = resolveMediaUrl(item['url']);")

# In All Photos Tab grid
$oldGridImg2 = @"
                          final item = _allPhotos[index];
                          final url = resolveMediaUrl(item['url']);
                          final caption = item['caption'] ?? 'Conference moment';
"@

$newGridImg2 = @"
                          final item = _allPhotos[index];
                          final thumbUrl = resolveMediaUrl(item['thumbnail_url'] ?? item['url']);
                          final fullUrl = resolveMediaUrl(item['url']);
                          final caption = item['caption'] ?? 'Conference moment';
"@

$content = $content.Replace($oldGridImg2, $newGridImg2)

# Update Image.network in both tabs to use thumbUrl and download button to use fullUrl
$content = $content.Replace("Image.network(`n                          url,", "Image.network(`n                          thumbUrl,")
$content = $content.Replace("Image.network(`n                                      url,", "Image.network(`n                                      thumbUrl,")
$content = $content.Replace("launchUrl(Uri.parse(url),", "launchUrl(Uri.parse(fullUrl),")

[System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
Write-Host "Updated Flutter thumbnail usage successfully!"
