Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime]
$awaiter = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await($operation, $type) {
  $task = $awaiter.MakeGenericMethod($type).Invoke($null, @($operation))
  $task.Wait()
  return $task.Result
}
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('ja'))
$taskRoot = Join-Path $PSScriptRoot '../tmp/basicjl'
foreach ($imageFile in Get-ChildItem -LiteralPath $taskRoot -Filter '*.png') {
  $output = [IO.Path]::ChangeExtension($imageFile.FullName, '.ocr.json')
  if (Test-Path -LiteralPath $output) { continue }
  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($imageFile.FullName)) ([Windows.Storage.StorageFile])
  $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
  $lines = @($result.Lines | ForEach-Object {
    @{text=$_.Text; words=@($_.Words | ForEach-Object { @{text=$_.Text; x=$_.BoundingRect.X; y=$_.BoundingRect.Y; width=$_.BoundingRect.Width; height=$_.BoundingRect.Height} })}
  })
  [IO.File]::WriteAllText($output, (ConvertTo-Json -InputObject $lines -Depth 8), [Text.UTF8Encoding]::new($false))
  $stream.Dispose()
  $bitmap.Dispose()
  Write-Output $imageFile.Name
}
