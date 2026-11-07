# WOLF-DUSK-044-CONT-002 — Android build checkpoint

Updated: 2026-11-07
Previous checkpoint: WOLF-DUSK-044-CONT-001

## Branch / repository
- Repository: Aa12345678arash/sheep-wolves-android
- Branch: WOLF-DUSK-044-COLLAGE-ASSET-INTEGRATION
- Prior checkpoint commit: 326a9e791903f6cb233cf7b2db011bdc89b86d2c
- This checkpoint records results from the build commit below; it does not declare visual milestone completion.

## Android build result
- Workflow: Build WOLF-DUSK-044 Android APK
- Run ID: 42387669592
- Run URL: https://github.com/Aa12345678arash/sheep-wolves-android/actions/runs/42387669592
- Built commit: 5510aba762e4b7cec321fa2125540a99ff41db16
- Final conclusion: success
- Setup, isolated branch checkout, Android export preset verification, Android export environment, Godot import/project validation, and startup/readability regression checks all passed.
- Android debug APK export and artifact upload completed successfully.

## Retrieved artifact and verification
- GitHub artifact ID: 13580650205
- Artifact name: wolf-dusk-044-android-preview
- Artifact ZIP: wolf-dusk-044-android-preview.zip
- ZIP size: 27,535,884 bytes
- ZIP SHA-256: c3914ffbee29be7dd7b36d3f282f26afd0e570036d33cd237795954376c162dd
- APK inside artifact: wolf-dusk-044-preview.apk
- APK size: 27,778,870 bytes
- APK SHA-256: 1830eb991025ff076b1eed8e60dbb1e08a03dc15d76b1eca653372dc1b0528b6
- The APK was extracted from the downloaded workflow artifact and its size/hash computed locally.
- APK archive inspection found Android launcher icon mipmap resources and packaged Godot resources.
- APK archive inspection also found the old project assets/icon.svg and assets/start_poster.svg. The newly approved collage crops were not present in this APK. Therefore this successful build is a build-pipeline baseline/preview, NOT the completed collage-integrated visual release.
- No phone installation or visual acceptance has been performed.

## Outstanding work
1. Transfer the approved collage source/crops into the repository using a real binary upload path and verify their exact Git tree entries.
2. Derive and install the approved upper-left icon panel as Android launcher/adaptive icon, then inspect the APK icon resources.
3. Replace the menu background with the approved lower-right panel.
4. Rebuild the active gameplay scene using the upper-right panel as a reference while keeping the board live and interactive.
5. Build lightweight 3D wolf/sheep models matching the lower-left reference; a flat image crop is not a 3D model.
6. Preserve existing rules, 5×5 board/56 connections, AI levels and controls.
7. Re-run Godot validation, gameplay/rule/AI tests, Android export, APK resource inspection, and provide a new APK/hash.
8. User must install and confirm appearance on phone before final acceptance.

## Continuation instruction
Resume with ID WOLF-DUSK-044-CONT-002. Preserve every approved constraint in CONT-001 and this document. Do not reset to a different design. Do not modify main or branch 041. At the end of each meaningful stage create the next sequential checkpoint ID (CONT-003, CONT-004, ...), recording commit, run IDs, evidence, hashes, and remaining tasks.
