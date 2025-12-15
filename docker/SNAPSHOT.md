# Docker Snapshot Guide

Location of snapshot exports (this repository):
- Image tag (default): `gnssfgo:built`
- Tar backup (default): `/home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built.tar`

Latest generated snapshot (timestamped):
- Image tag: `gnssfgo:built-20251215-1638`
- Tar backup: `/home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built_20251215-1638.tar`

## Reuse the saved snapshot
```bash
# Load the tar if needed
docker load -i /home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built_20251215-1638.tar

# Run interactively (matches compose settings: host net, privileged, serial, GUI)
docker run --rm -it --network host --privileged \
  --device /dev/ttyACM0 --device /dev/ttyACM1 \
  -v /mnt/DataSmall:/Data -v /tmp/.X11-unix:/tmp/.X11-unix \
  gnssfgo:built-20251215-1638 bash
```

### Use with docker compose
- Option 1: Temporarily override in compose: set `image: gnssfgo:built-20251215-1638` and `docker compose up -d`.
- Option 2: Run with the `docker run` command above.

## Save a new snapshot later (host)
Run these on the host while the container is in the desired state:
```bash
# 1) Create a timestamped image from the running container
DATE=$(date +%Y%m%d-%H%M)
docker commit gnssfgo gnssfgo:built-$DATE

# 2) Export to tar for backup/move
docker save -o /home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built_$DATE.tar gnssfgo:built-$DATE
```

## Roll back to a previous snapshot
```bash
# Load the archived snapshot (if not already loaded)
docker load -i /home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built_20251215-1638.tar

# (Optional) keep a copy of current before switching
docker tag gnssfgo:built-20251215-1638 gnssfgo:backup-$(date +%Y%m%d)
```

## Clean up old snapshots
```bash
# Remove an old tag
docker rmi gnssfgo:oldtag

# Delete an old archive
rm /path/to/old_snapshot.tar
```

Notes:
- Snapshotting does not require rebuilding the image.
- Use timestamped tags to keep multiple snapshots and make rollbacks easier.

## Example: create a new timestamped snapshot (one-liner)
```bash
DATE=$(date +%Y%m%d-%H%M); docker commit gnssfgo gnssfgo:built-$DATE; docker save -o /home/om/Projects/hiwi/Hiwi_project_gnnss/gnssfgo_built_$DATE.tar gnssfgo:built-$DATE
```
