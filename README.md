# Docmost Installation Guide

This guide will show you how to install **Docmost** on your machine, using **Docker**, **Rclone** and **crontab** to setup weekly backups for your instance

## Prerequisites

Before installing Docmost, ensure that the `.env.template` file is properly completed and configured. All the purposes of the variables are defined inside the template file.

Additionally, make sure the following tools are installed on your machine:

- `zip`
- `unzip`
- `docker`
- `rclone`
- `crontab`

### Docker

Docmost requires Docker to function properly. Follow the official instructions to install Docker based on your operating system:

[Docker Installation Guide](https://docs.docker.com/get-docker/)

### Rclone

Rclone is a tool for syncing and managing files in cloud storage. It will allow you to store your backups on your **Proton Drive** account.

**Installation:**
```sh
sudo -v ; curl https://rclone.org/install.sh | sudo bash -s beta
```

## Setting up Rclone to Access Proton Drive

After installing Rclone, follow these steps to configure it for Proton Drive:

1. Run the configuration command:
   ```sh
   rclone config
   ```
2. Enter **n** to create a new remote.
2. Give a name to the remote: use the same name as specified in the `.env` file for `RCLONE_REMOTE_NAME`.
3. Then, a list of configurations should appear, you need to enter **Proton Drive** id (which is as of today **43** or **protondrive**)
3. Enter your username and password, leaving the rest of the settings as default.

<div style="border: 2px solid red; padding: 10px;">
<strong>Warning:</strong> After setting up your credentials, you must first log in to your account via a browser using <strong>EXACTLY</strong> the same credentials as the one you provided. Otherwise, you may encounter an error requiring you to validate a captcha.
</div>

<div style="border: 2px solid orange; padding: 10px; margin-top: 10px;">
<strong>Note:</strong> If you cannot see <strong>Proton Drive</strong> in the list of configurations available, verify your Rclone version. You need to have Rclone in a beta version as <strong>Proton Drive</strong> is currently a beta feature.
</div>

### Testing the Setup

To verify that Rclone is correctly set up, run:
```sh
rclone ls $RCLONE_REMOTE_NAME:
```

A list of the files stored in your **Proton Drive** account should appear.

Once these prerequisites are installed and configured, you can proceed with installing Docmost.

## Setting up Docmost with `start_docker.sh`

To start Docmost, use the `docker-compose.yml` file. Before running it, make sure you have set the required environment variables:

- `APP_URL`: The base URL of your Docmost instance.
- 
- `PG_PASSWORD`: The PostgreSQL password.

### Running the Script

Once the environment variables are set, execute the following command:
```sh
docker compose up -d
```

This will initialize **Docmost** and **PostgreSQL** using Docker.

## Setting up a Cron Job for Database Backup

To automatically back up your Docmost database every Monday at 8 PM (as described in the below example), you need to create a cron job that runs `save_backup.sh`.

### Adding the Cron Job

1. Open the cron job editor:
   ```sh
   crontab -e
   ```
2. Add the following line at the end of the file:
   ```sh
   0 20 * * 1 cd /home/ubuntu/doc/backup && ./save_backup.sh >> backups.log 2>&1
   ```
   - `0 20 * * 1` means the script will run at 20:00 (8 PM) every Monday.
   - `cd /home/ubuntu/doc/backup &&` is mandatory to find .env
   - `>> backups.log` append logs to backups.log
   - `2>&1` redirects stderr to stdout

    **TODO** : voir pour avoir un fichier de log pour chaque backup
3. Save and exit the editor.

### Verifying the Cron Job

To check if the cron job is set up correctly, run:
```sh
crontab -l
```
This should display the newly added cron job.

Now, your database backups will automatically run every Monday at 8 PM.

## Restoring a Backup with `restore_backup.sh`

To restore a specific database backup using `restore_backup.sh`, follow these steps:

### Running the Restore Script

Execute the following command, replacing `<backup-file.tar.gz>` with the actual backup file you want to restore:
```sh
./restore_backup.sh /path/to/<backup-file.tar.gz>
```

### Notes:
- Ensure that the backup file exists and is accessible before running the script.
- The restore process will replace the current database with the backup version.

Now, you can use `restore_backup.sh` to revert to a specific backup whenever necessary.
