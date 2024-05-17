# EZB (Easy Backup) Command Line Tool

![EZB LOGO](ezb_logo.jpg)

EZB is a command-line tool designed to simplify backing up files to Backblaze B2 cloud storage. It supports various backup functionalities including automatic, threaded, and forked backups.

## Installation

To install EZB, run the following command:
```sh
chmod +x ezb
sudo ./ezb.sh -i
```

## Commands and Usage

### Help
Displays help information about the EZB tool.
```sh
ezb -h
```

### Manual Backup
Manually backup a specified file to Backblaze B2.
```sh
sudo ezb -m -s <filename> -n <name>
```

- `<filename>`: The name of the file to be backed up.
- `<name>`: The name to assign to the backup in B2.

### Automatic Backup
Automatically backup a specified file to Backblaze B2.
```sh
sudo ezb -a -s <filename> -n <name>
```

- `<filename>`: The name of the file to be backed up.
- `<name>`: The name to assign to the backup in B2.

### View Log
View the backup log to see the history and status of backups.
```sh
sudo ezb -l
```

### Restore Backup
Restore a file from Backblaze B2.
```sh
ezb -r
```

### Threaded Backup
Perform a threaded backup of a specified folder to Backblaze B2.
```sh
sudo ezb -t -m -s <foldername> -n <name>
```

- `<foldername>`: The name of the folder to be backed up.
- `<name>`: The name to assign to the backup in B2.

### Forked Backup
Perform a forked backup of a specified folder to Backblaze B2.
```sh
sudo ezb -fo -m -s <foldername> -n <name>
```

- `<foldername>`: The name of the folder to be backed up.
- `<name>`: The name to assign to the backup in B2.

### Configure
Configure EZB with your Backblaze B2 credentials.
```sh
sudo ezb -co <b2_api_key> <b2_id> <b2_bucket_name>
```

- `<b2_api_key>`: Your Backblaze B2 API key.
- `<b2_id>`: Your Backblaze B2 account ID.
- `<b2_bucket_name>`: The name of your Backblaze B2 bucket.

## Examples

1. **Manual Backup**:
   ```sh
   sudo ezb -m -s /path/to/file.txt -n my_backup
   ```

2. **Automatic Backup**:
   ```sh
   sudo ezb -a -s /path/to/file.txt -n my_auto_backup
   ```

3. **Threaded Backup**:
   ```sh
   sudo ezb -t -m -s /path/to/folder -n my_threaded_backup
   ```

4. **Forked Backup**:
   ```sh
   sudo ezb -fo -m -s /path/to/folder -n my_forked_backup
   ```

5. **Configure EZB**:
   ```sh
   sudo ezb -co your_b2_api_key your_b2_id your_b2_bucket_name
   ```

## Additional Information

For more detailed usage and options, refer to the help command:
```sh
ezb -h
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Backblaze B2 Cloud Storage

For support or further information, please contact the project maintainers.