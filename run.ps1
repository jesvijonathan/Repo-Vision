
Write-Host "Loading environment variables..."
$skippedEnvVars = @()
Get-Content .env | ForEach-Object {
    $name, $value = $_ -split '=', 2
    if ($value -and -not [System.Environment]::GetEnvironmentVariable($name, "Process")) {
        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    } else {
        $skippedEnvVars += $name
    }
}
if ($skippedEnvVars.Count -gt 0) {
    Write-Host "Skipped environment variables: $($skippedEnvVars -join ', ')"
} else {
    Write-Host "No environment variables were skipped."
}

$pythonInstalled = Get-Command python -ErrorAction SilentlyContinue
if ($pythonInstalled) {
    Write-Host "✔ Python already installed."
} else {
    Write-Host "Python is not installed. Installing Python 3.10.1..."
    $installerUrl = "https://www.python.org/ftp/python/3.10.1/python-3.10.1-amd64.exe"
    $installerPath = "$env:TEMP\python-3.10.1-amd64.exe"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
    Remove-Item $installerPath
    Write-Host "Python Installed successfully."
}
python --version

$pipInstalled = Get-Command pip -ErrorAction SilentlyContinue
if ($pipInstalled) {
    Write-Host "✔ PIP already installed"
} else {
    Write-Host "PIP not present. Installing PIP..."
    $pipInstallerUrl = "https://bootstrap.pypa.io/get-pip.py"
    $pipInstallerPath = "$env:TEMP\get-pip.py"
    Invoke-WebRequest -Uri $pipInstallerUrl -OutFile $pipInstallerPath
    python $pipInstallerPath
    Remove-Item $pipInstallerPath
    Write-Host "PIP Installed successfully."
}
pip --version

$virtualenvInstalled = Get-Command virtualenv -ErrorAction SilentlyContinue
if ($virtualenvInstalled) {
    Write-Host "✔ Virtualenv already installed"
} else {
    Write-Host "Virtualenv not present. Installing Virtualenv..."
    pip install virtualenv
    Write-Host "Virtualenv Installed successfully."
}
virtualenv --version

$venvPath = ".\.venv"
if (Test-Path $venvPath) {
    Write-Host "✔ Virtual environment already exists."
} else {
    Write-Host "Creating virtual environment..."
    virtualenv $venvPath
    Write-Host "Virtual environment created successfully."
}
.\.venv\Scripts\Activate.ps1

Write-Host "Installing dependencies..."
pip install -r requirements.txt
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
Write-Host "✔ Dependencies installed successfully."

$model = $env:model
$modelsPath = "./models/$model"
if (-Not (Test-Path $modelsPath)) {
    Write-Host "$modelsPath missing, using default 'DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf' model..."
    [System.Environment]::SetEnvironmentVariable("model", "DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf", "Process")
    $modelsUrl = "https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf"
    Invoke-WebRequest -Uri $modelsUrl -OutFile $modelsPath
} else {
    Write-Host "✔ Model present."
}

$llamaServerPath = "./bin/llama/llama-server.exe"
if (-Not (Test-Path $llamaServerPath)) {
    Write-Host "Downloading Llama cpp"

    $githubReleaseUrl = "https://github.com/ggerganov/llama.cpp/releases/download/b4595/llama-b4595-bin-win-cuda-cu12.4-x64.zip"
    $llamaZipPath = "$env:TEMP\llama-b4595-bin-win-cuda-cu12.4-x64.zip"
    Invoke-WebRequest -Uri $githubReleaseUrl -OutFile $llamaZipPath
    Expand-Archive -Path $llamaZipPath -DestinationPath "./bin/llama" -Force
    Remove-Item $llamaZipPath
    Write-Host "Llama cpp downloaded successfully."

    # $githubReleaseUrl = "https://github.com/ggerganov/llama.cpp/releases/latest" # why are we doing this ? cuase it flags the zip as a potential virus
    # Write-Host "Opening browser.., please download -bin-win-cuda-cu12.4-x64.zip and extract it into ./bin/llama"
    # Start-Process $githubReleaseUrl
    # Start-Process explorer -ArgumentList "$(Resolve-Path ./bin/llama)"
} else {
    Write-Host "✔ Llama server present."
}

$llamaServerRunning = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
if ($llamaServerRunning) {
    Write-Host "✔ Llama server already running."
} else {
    Write-Host "Starting Llama server..."
    Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoExit", "-File", "./bin/start_llama_server.ps1"
    Write-Host "Loading Llama server..."
    Start-Sleep -Seconds 3
}

Write-Host "Starting app.."
# Set-Location ./app
# python ./app/main.py