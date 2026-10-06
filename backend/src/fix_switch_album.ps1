$filePath = "d:\conference_app\flutter_app\lib\main.dart"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)

$oldLoad = @"
  Future<void> _loadAllPhotos({bool refresh = false}) async {
    if (_isLoadingAllPhotos) return;
    if (refresh) {
      _currentPage = 1;
      _hasMoreAllPhotos = true;
    }
    if (!_hasMoreAllPhotos) return;

    setState(() => _isLoadingAllPhotos = true);
"@

$newLoad = @"
  Future<void> _loadAllPhotos({bool refresh = false}) async {
    if (_isLoadingAllPhotos && !refresh) return;
    if (refresh) {
      _currentPage = 1;
      _hasMoreAllPhotos = true;
    }
    if (!_hasMoreAllPhotos) return;

    setState(() => _isLoadingAllPhotos = true);
"@

$content = $content.Replace($oldLoad, $newLoad)

$oldSwitch = @"
  void _switchAlbum(String album) {
    if (_activeAlbum == album) return;
    setState(() {
      _activeAlbum = album;
      _allPhotos.clear();
      _isLoadingAllPhotos = true;
    });
    _loadAllPhotos(refresh: true);
  }
"@

$newSwitch = @"
  void _switchAlbum(String album) {
    if (_activeAlbum == album) return;
    setState(() {
      _activeAlbum = album;
      _allPhotos.clear();
      _isLoadingAllPhotos = true;
      _hasMoreAllPhotos = true;
      _currentPage = 1;
    });
    _loadAllPhotos(refresh: true);
  }
"@

$content = $content.Replace($oldSwitch, $newSwitch)

[System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
Write-Host "Fixed _switchAlbum and _loadAllPhotos in main.dart successfully!"
