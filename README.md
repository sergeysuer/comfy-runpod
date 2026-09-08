# comfy-runpod

One Docker image that runs ComfyUI two ways on RunPod.

| Env var | Value | What happens |
|---|---|---|
| `MODE` | `pod` | ComfyUI web UI on port 8188 |
| `MODE` | `serverless` | RunPod job handler (default) |

Models live on the **network volume**, never in the image.

## To add or remove a custom node

1. Open `nodes.txt` here on GitHub
2. Click the pencil icon
3. Add a git URL on its own line, or put `#` in front of a line to switch it off
4. Click **Commit changes**

GitHub rebuilds the image automatically. Watch it in the **Actions** tab.
Takes roughly 20-40 minutes.

## Image address

```
ghcr.io/<your-github-username>/comfy-runpod:latest
```

Paste that into RunPod's *Container Image* field.

## Files

| File | Purpose |
|---|---|
| `nodes.txt` | The list of custom nodes. **The only file you normally touch.** |
| `Dockerfile` | The recipe. Change `BASE_TAG` to move to a newer ComfyUI base. |
| `scripts/install_nodes.sh` | Clones each node and installs its requirements at build time. |
| `scripts/start.sh` | Picks pod or serverless mode at launch; points ComfyUI at the volume. |
| `.github/workflows/build.yml` | Tells GitHub to build and publish the image. |

## If a build fails

Open **Actions**, click the red run, read the log. Node failures are listed
under `NODE INSTALL SUMMARY`. Comment the offending line out in `nodes.txt`
and commit again.
