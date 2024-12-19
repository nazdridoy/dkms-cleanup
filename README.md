# DKMS Cleanup Script

This is a Bash script designed to clean up leftover DKMS (Dynamic Kernel Module Support) artifacts after upgrading module sources or removing kernels. The script helps maintain a clean system by removing unnecessary DKMS directories and files associated with non-existent kernels.

## Features

- **Dry Run**: Run the script as a non-root user to perform a preliminary check of DKMS artifacts.
- **Automated Cleanup**: Automatically removes DKMS directories and files for kernels that no longer exist.
- **Logging**: Provides informative logging with color-coded messages for easy readability.


## Usage

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/nazdridoy/dkms-cleanup.git
   cd dkms-cleanup
   ```

2. **Run the Script**:
   - As a non-root user for a preliminary check:
     ```bash
     ./dkms-cleanup.sh
     ```
   - As root to perform the cleanup:
     ```bash
     sudo ./dkms-cleanup.sh
     ```

## Important Notes

- **Caution**: Always run the script as a non-root user first to understand what changes will be made.
- **Backup**: Consider backing up important data before running the script as root.

## Contributing

This is for mainly for my personal use (Archlinux) but contributions are welcome! Please fork the repository and submit a pull request with your improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
