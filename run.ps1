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

$modelsPath = "./models/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf"
if (-Not (Test-Path $modelsPath)) {
    Write-Host "Downloading models..."
    $modelsUrl = "https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q8_0.gguf"
    Invoke-WebRequest -Uri $modelsUrl -OutFile $modelsPath
} else {
    Write-Host "✔ Model present."
}

$llamaServerPath = "./bin/llama/llama-server.exe"
if (-Not (Test-Path $llamaServerPath)) {
    Write-Host "Downloading Llama cpp"
    $githubReleaseUrl = "https://github.com/ggerganov/llama.cpp/releases/download/b4595/llama-b4595-bin-win-cuda-cu12.4-x64.zip"
    # if ($downloadLink) {
    #     $destinationPath = "./bin/llama/"
    #     Write-Host "Downloading from: $githubReleaseUrl"
    #     Invoke-WebRequest -Uri $githubReleaseUrl -OutFile "$destinationPath/llama.zip"
    #     Write-Host "Download completed to: $destinationPath"
    #     # extract the zip file
    #     Expand-Archive -Path "$destinationPath/llama.zip" -DestinationPath ./ -Force
    #     Write-Host "Extracted to: $destinationPath"
    # } 
    else {
        Write-Host "No matching file found."
    }
} else {
    Write-Host "✔ Llama server present."
}

Write-Host "Running the application..."
Set-Location ./app
python main.py
