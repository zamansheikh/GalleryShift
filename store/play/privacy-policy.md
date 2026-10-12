# GalleryShift privacy policy

Effective 12 October 2026

Published at https://zamansheikh.github.io/GalleryShift/privacy/ from `docs/privacy/index.html`. The two hold the same text: change both together.

**In short:** GalleryShift does not collect, send or share any of your data. Everything it does happens on your phone. The app has no permission to use the internet.

GalleryShift is a photo and storage cleanup app for Android, made by Zaman Sheikh. This policy explains what the app can access on your phone, what it keeps, and what it never does.

## What the app accesses, and why

- **Your photos and videos.** The app needs access to your photo library to show you each photo and video and to delete the ones you choose. They are read on your phone only. They are never uploaded, copied off the phone or shared.
- **All files (optional).** If you open Storage cleanup and turn on "All files access", the app looks through your phone's shared storage to find junk files, empty folders, large files and documents, and deletes the ones you pick. It reads file names, sizes and dates. It does not read what is inside your files, and it never looks in other apps' private folders. You can turn this access off again at any time in Android Settings. Swiping photos works without it.

## What the app keeps on your phone

- Your keep and delete decisions: an identifier for each photo and the time it was taken.
- Your totals: space freed and items deleted.
- Small settings, such as whether video sound is on and whether you have seen the introduction.
- For about a month, the names of files you deleted through the app, so the same space is not counted twice.

This is stored in the app's private storage on your phone. It is left out of Android's cloud backup and phone-to-phone transfer. Uninstalling the app removes all of it, and "Start over" in the app's menu clears your decisions.

## What the app does not do

- It has no account and no sign-in.
- It shows no ads and contains no analytics, crash reporting or tracking.
- It does not have Android's internet permission, so it cannot send data anywhere.
- It does not sell or share data with anyone, because it has none to share.

## Deleting photos and files

The app always asks before deleting. On Android 11 and newer, photos and videos you delete go to your phone's trash, where they stay for 30 days and can be restored from your gallery or Files app. Android 10 and older have no trash, so photos are deleted permanently there; the app says so first. Files deleted in Storage cleanup are always deleted permanently.

## Other apps and websites

- If you tap a document in Storage cleanup, Android opens it in an app you choose. That app then handles the file under its own policy.
- The About screen has links to the developer's GitHub and Facebook pages. They open in your browser, and those sites have their own privacy policies.

## Permissions the app asks for

| Permission | Used for |
|---|---|
| Photos and videos: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`; on Android 12 and older `READ_EXTERNAL_STORAGE`, and `WRITE_EXTERNAL_STORAGE` on Android 10 and older | Showing your photos and videos and deleting the ones you choose |
| All files access: `MANAGE_EXTERNAL_STORAGE` | Storage cleanup only, and only if you turn it on |
| Network state and wake lock: `ACCESS_NETWORK_STATE`, `WAKE_LOCK` | Added by the video player component. They let it check whether a network exists and keep the phone awake while a video plays. They do not allow sending or receiving data. |

## Children

GalleryShift is not directed at children, and it collects no personal information from anyone.

## Changes to this policy

If this policy changes, the new version will be published at this address with a new date.

## Contact

Questions about privacy? Open an issue at https://github.com/zamansheikh/GalleryShift/issues
