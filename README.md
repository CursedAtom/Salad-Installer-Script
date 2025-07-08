# Salad-Installer-Script

This script downloads and installs:
- WSL (`wsl --install --no-distribution`)
- [VC_Redist](https://aka.ms/vs/17/release/vc_redist.x64.exe)
- [.NET Framework 4.8](https://go.microsoft.com/fwlink/?linkid=2088631)
- [Latest Salad Version](https://releases.salad.com/release/latest.yml)
- [NVIDIA Studio Driver 576.80](https://us.download.nvidia.com/Windows/576.80/576.80-desktop-win10-win11-64bit-international-nsd-dch-whql.exe) (If a NVIDIA GPU is installed)

The Script also prompts the user to:
- Add Salad to Startup apps
- Clean up temporary files downloaded during installation
- Restart the computer

Use the flag `./InstallSalad.cmd -y` to skip user prompts (will automatically clean up temp files and reboot, save your work before continuing)

# 
Additionally, the script checks if Virtualization is enabled and attempts to enable it if not. You may need to follow [this guide](https://support.salad.com/article/270-how-to-enable-virtualization-support-on-your-machine) to finish enabling virtualization if the step fails.
