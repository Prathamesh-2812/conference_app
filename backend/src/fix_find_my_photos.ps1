$filePath = "d:\conference_app\flutter_app\lib\main.dart"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

# Remove _loadInitialMatchedPhotos() call from initState
$oldInit = @"
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialMatchedPhotos();
    _loadAlbums();
    _loadAllPhotos(refresh: true);
"@

$newInit = @"
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAlbums();
    _loadAllPhotos(refresh: true);
"@

$content = $content.Replace($oldInit, $newInit)

[System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
Write-Host "Updated main.dart initState successfully!"
