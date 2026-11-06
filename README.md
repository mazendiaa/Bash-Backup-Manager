# Bash Backup Manager

A Bash-based automated backup management system with Docker support. It provides an interactive CLI to create, restore, delete, and manage backups, with automated scheduling and backup retention.

## Features

- **Create Backups:** Compress source directories into `.tar.gz` archives.
- **Backup Verification:** Verify archive integrity after creation.
- **Restore Backups:** Preview archive contents before restoring.
- **Backup Management:** List and delete existing backups.
- **Automated Scheduling:** Schedule daily, weekly, or monthly backups using Cron.
- **Backup Retention:** Automatically remove old backups while keeping a configurable number of recent backups.
- **Logging:** Record backup operations and errors.
- **Metadata:** Store backup information, including source path, creation date, size, and verification status.
- **Docker Support:** Run the application inside an Ubuntu-based container.
- **Persistent Storage:** Keep backup files and Cron schedules across container recreation.

## Technologies Used

- Bash Scripting
- Linux
- Cron
- Docker
- Docker Compose
- Ubuntu 24.04
- tar

## Project Structure

```text
Bash_Projects/
├── .dockerignore
├── compose.yaml
├── project1.sh
└── docker/
    ├── Dockerfile
    ├── entrypoint.sh
    └── backups/
```

## Requirements

- Linux or WSL2
- Docker Engine or Docker Desktop
- Docker Compose

## Installation & Usage

### 1. Clone the Repository

```bash
git clone <https://github.com/mazendiaa/Bash-Backup-Manager.git>
cd Bash_Projects
```

### 2. Configure the Source Directory

By default, Docker Compose mounts:

```text
${HOME}/data
```

as:

```text
/app/source
```

Create the source directory if it does not exist:

```bash
mkdir -p ~/data
```

### 3. Build and Start the Container

```bash
docker compose up -d --build
```

### 4. Run the Backup Manager

```bash
docker compose exec backup-manager bash /app/backup.sh
```

The interactive menu will appear, allowing you to manage backups.

## Backup Storage

Backup archives are stored on the host machine in:

```text
docker/backups/
```

The container uses a bind mount to keep backup files persistent even if the container is removed.

The source directory is mounted as read-only to prevent accidental modifications to original files.

## Automated Backups

The application uses Cron to schedule automatic backups.

You can configure:

- Daily backups
- Weekly backups
- Monthly backups

Cron jobs are stored in a Docker named volume to preserve scheduling configuration across container recreation.

## Backup Retention

Configure the maximum number of backups to keep.

After a successful backup, the retention mechanism checks existing archives and removes older backups exceeding the configured limit.

## Useful Docker Commands

Start the application:

```bash
docker compose up -d
```

Stop the application:

```bash
docker compose stop
```

View container status:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs backup-manager
```

Open the interactive application:

```bash
docker compose exec backup-manager bash /app/backup.sh
```

Stop and remove containers:

```bash
docker compose down
```

**Note:** Avoid `docker compose down -v` unless you intentionally want to remove the named volumes, including persisted Cron data.

## Future Improvements

- User and group permission management.
- Email notifications.
- JSON backup reports.
- Docker health checks.
- Systemd integration.
- Web-based monitoring dashboard.

## Author

**Mazen Diaa Eldin Ahmed**

[GitHub](https://github.com/mazendiaa) · [LinkedIn](https://www.linkedin.com/in/mazen-diaa-5957a0286/)
