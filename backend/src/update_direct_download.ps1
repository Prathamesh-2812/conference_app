$filePath = "d:\conference_app\flutter_app\lib\main.dart"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

$oldViewerBtn = @"
                    onPressed: () {
                      launchUrl(Uri.parse(photoUrl), mode: LaunchMode.externalApplication);
                    },
"@

$newViewerBtn = @"
                    onPressed: () {
                      final downloadUrl = resolveMediaUrl('/api/download?url=' + Uri.encodeComponent(photoUrl));
                      launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                    },
"@

$content = $content.Replace($oldViewerBtn, $newViewerBtn)

# In AI Selfie card download icon
$oldCardBtn1 = @"
                            child: InkWell(
                              onTap: () {
                                launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
                              },
"@

$newCardBtn1 = @"
                            child: InkWell(
                              onTap: () {
                                final downloadUrl = resolveMediaUrl('/api/download?url=' + Uri.encodeComponent(fullUrl));
                                launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                              },
"@

$content = $content.Replace($oldCardBtn1, $newCardBtn1)

# In All Photos card download icon
$oldCardBtn2 = @"
                                  child: InkWell(
                                    onTap: () {
                                      launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
                                    },
"@

$newCardBtn2 = @"
                                  child: InkWell(
                                    onTap: () {
                                      final downloadUrl = resolveMediaUrl('/api/download?url=' + Uri.encodeComponent(fullUrl));
                                      launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                                    },
"@

$content = $content.Replace($oldCardBtn2, $newCardBtn2)

[System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
Write-Host "Updated direct file downloading in Flutter main.dart successfully!"
