# Windows x64 Build — Troubleshooting Guide (English)

This document complements the Persian setup guide (`local-windows-x64-setup.md`) and explains the common failures observed in the Windows PowerShell build logs, plus the script fixes applied.

---

## 1. Quick summary of errors from the log

| Symptom in log | Root cause | Fix applied |
|---|---|---|
| `WSL ERROR: execvpe(/bin/bash) failed` | Git Bash / WSL bash is not installed or `bash` is not in `PATH`. | Ensure Git for Windows (with Git Bash) is installed. The scripts keep the bash dependency. |
| `The system cannot find the path specified.` when reading `build.artifacts\env\build_mode.env` | The env file was never generated because `make_build_mode_env.sh` failed. | Added `IF NOT EXIST ...` checks in `build.bat` and `package.bat` with clear error messages. |
| `( was unexpected at this time.` after `SET "MUSE_APP_BUILD_MODE=dev"` | `BUILD_MODE` was empty, making `IF == devel` invalid batch syntax. | Added `IF "%BUILD_MODE%" == "" ( ... EXIT /b 1 )` guard before the `IF` chain. |
| `CMake Error: The source directory ... does not appear to contain CMakeLists.txt` | `package.bat` tried to run CMake in `build.release` which either does not exist or was not configured properly. | Ensure `build.bat` completes successfully (creating `build.release`) before running `package.bat`. The docs now explicitly state this prerequisite. |
| `File not found - WIX` when copying MSI logs | The MSIs were never produced (CMake/package step failed). | Same fix: complete the build first, then package. |

---

## 2. Script fixes made in this repository

### `buildscripts/ci/windows/build.bat`

- Added file-existence check for `build.artifacts/env/build_mode.env` before reading it.
- Added empty-string guard for `BUILD_MODE` before the nested `IF` chain.
- Added file-existence check for `build_revision.env` and empty-string guard for `MUSESCORE_REVISION`.
- Improved error messages that tell the user exactly which bash command to run.

### `buildscripts/ci/windows/package.bat`

- Added file-existence check for `build.artifacts/env/build_mode.env`.
- Added loop to verify all required env files (`build_version.env`, `build_number.env`, `build_branch.env`, `build_revision.env`) exist before reading them.
- Added empty-string guards for each read variable.

---

## 3. Prerequisites that must be satisfied before running `.bat` scripts

1. **Generate build metadata** (requires bash, from Git Bash or WSL):
   ```bash
   bash buildscripts/ci/tools/make_build_mode_env.sh -e workflow_dispatch -m stable
   bash buildscripts/ci/tools/make_build_number.sh 2026090501
   ```

2. **Run `setup.bat`** (downloads dependencies to `C:\musescore_dependencies` and installs Jack headers):
   ```bat
   buildscripts\ci\windows\setup.bat
   ```

3. **Run `build.bat`** before `package.bat` (creates `build.release`, `build.install`, and the env files):
   ```bat
   buildscripts\ci\windows\build.bat -n 2026090501 --dockwidgets_v2 ON
   ```

4. **Only then run `package.bat`**:
   ```bat
   buildscripts\ci\windows\package.bat -m stable --guid 11111111-1111-1111-1111-111111111111
   ```

---

## 4. If bash is unavailable

The scripts rely on bash for:
- `buildscripts/ci/tools/make_build_mode_env.sh`
- `buildscripts/ci/tools/make_build_number.sh`
- `buildscripts/ci/tools/make_revision_env.sh`
- `buildscripts/ci/tools/make_release_channel_env.sh`
- `buildscripts/ci/tools/make_version_env.sh`
- `buildscripts/ci/tools/make_branch_env.sh`
- `buildscripts/ci/tools/make_artifact_name_env.sh`

If `bash` is unavailable:
- Install **Git for Windows** (includes `git-bash.exe` and puts `bash` on `PATH`).
- Or install **WSL** and ensure `/bin/bash` exists.
- The scripts intentionally keep the bash dependency (per user request) rather than rewriting everything in pure batch.

---

## 5. Notes on the existing Persian guide (`docs/local-windows-x64-setup.md`)

The Persian guide remains the authoritative reference. This English document is intended for:
- Quick error lookup.
- Understanding the exact `.bat` changes made in this branch (`arena/01a0734f-musescore`).
- Non-Persian contributors working on the build pipeline.
