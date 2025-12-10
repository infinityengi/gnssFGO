# Docker Snapshot Guide

Location of current snapshot export:
- Image tag: `gnssfgo:built`
- Tar backup: `/home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built.tar`

## Reuse the saved snapshot
```bash
# Load the tar if needed
docker load -i /home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built.tar

# Run interactively (matches compose settings: host net, privileged, serial, GUI)
docker run --rm -it --network host --privileged \
  --device /dev/ttyACM0 --device /dev/ttyACM1 \
  -v /mnt/DataSmall:/Data -v /tmp/.X11-unix:/tmp/.X11-unix \
  gnssfgo:built bash
```

### Use with docker compose
- Option 1: Temporarily override in compose: set `image: gnssfgo:built` and `docker compose up -d`.
- Option 2: Run with `docker run` command above.

## Save a new snapshot later
Run these on the host while the container is in the desired state:
```bash
# 1) Commit running container to an image tag
docker commit gnssfgo gnssfgo:built

# 2) Optional: export to tar for backup/move
docker save -o /home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built.tar gnssfgo:built
```

## Roll back to a previous snapshot
```bash
# Load the archived snapshot (if not already loaded)
docker load -i /home/om/Projects/hiwi/Hiwi_project_gnss/gnssfgo_built.tar

# (Optional) keep a copy of current before switching
docker tag gnssfgo:built gnssfgo:backup-$(date +%Y%m%d)
```

## Clean up old snapshots
```bash
# Remove an old tag
docker rmi gnssfgo:oldtag

# Delete an old archive






- Keep the tar somewhere backed up if you need to restore on another machine.- Snapshotting does not require rebuilding the image.Notes:```m /path/to/old_snapshot.tar