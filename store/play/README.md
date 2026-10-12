# Publishing GalleryShift on Google Play

Everything Play Console asks for, in the order it asks. Prepared for version 1.0.0 (version code 1) on 12 October 2026. Nothing has been uploaded yet.

## In this folder

| File | What it is |
|---|---|
| `listing.md` | App name, short and full description, release notes, category, the web addresses |
| `privacy-policy.md` | The privacy policy text. Published at https://zamansheikh.github.io/GalleryShift/privacy/ from `docs/privacy/index.html`; change both together |
| `console-answers.md` | Answers for Data safety, content rating, target audience, ads, and the two permission declarations |
| `icon-512.png` | Store icon |
| `feature-graphic.png` | Feature graphic (the banner at the top of the listing) |
| `screenshots/` | Eight phone screenshots, numbered in listing order |
| `all-files-access-demo.mp4` | A 71-second captioned screen recording of Storage cleanup, for the All files access declaration. Silent |
| `captures/` | The raw device screenshots the graphics are built from |

The app bundle is built with `flutter build appbundle --release` and lands in `build/app/outputs/bundle/release/app-release.aab`.

To redraw the graphics after changing a capture or a headline:

```bash
flutter test tool/store_graphics_test.dart && tool/finish_store_graphics.sh
```

## Checked on the 1.0.0 bundle

| | |
|---|---|
| Package name | `com.silifton.galleryshift` |
| Version | 1.0.0, version code 1 |
| Signed by | CN=Zaman Sheikh, O=Silifton, SHA-256 `39:BD:53:01 ... 92:09:3F:16` |
| Target API level | 36 (Android 16). Minimum 24 (Android 7.0) |
| 16 KB page size | `zipalign -c -P 16` passes, and the release build ran on a 16 KB page emulator of Android 17 |
| Internet permission | Not in the bundle |
| Advertising ID permission | Not in the bundle |
| Listing text | Name 27 of 30 characters, short description 79 of 80, full description 2,408 of 4,000, release notes 150 of 500 |
| Graphics | Icon 512 x 512, feature graphic 1024 x 500, screenshots 1242 x 2208, all 24-bit PNG with no transparency |

Permissions in the bundle: read images and video (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`), read and write external storage on older Android only (`READ_EXTERNAL_STORAGE` up to Android 12, `WRITE_EXTERNAL_STORAGE` up to Android 10), all files access (`MANAGE_EXTERNAL_STORAGE`), and `ACCESS_NETWORK_STATE` and `WAKE_LOCK`, which the video player library adds.

The delete flow, the review bin and Storage cleanup were run on emulators of Android 10, 13 and 17.

## Before you open Play Console

Four things only you can do.

1. **Back up the upload key.** `galleryshift-release.jks` and `keystore.properties` are in `~/Documents/silifton/Docs-Files-IMPORTANT/galleryshift-android-signing/` and nowhere else. Put a copy somewhere off this machine.
2. **Choose the contact email.** Play shows it publicly on the listing. The privacy policy points to the issue tracker, so it needs no change.
3. **Check the website is live.** Open https://zamansheikh.github.io/GalleryShift/ and https://zamansheikh.github.io/GalleryShift/privacy/ in a browser. Play rejects a privacy policy address that does not load. The site is served by GitHub Pages from `docs/` on the `main` branch.
4. **Upload the video.** Put `all-files-access-demo.mp4` somewhere it can be watched, an unlisted YouTube video for one, and keep the link for step 6. Watch it once first.

## Steps in Play Console

1. **Create the app.** Name `GalleryShift: Photo Cleaner`, default language English (United States), App, Free. Accept the declarations.
2. **Store listing.** Paste the short and full description from `listing.md`. Upload `icon-512.png`, `feature-graphic.png` and the eight files in `screenshots/` as phone screenshots, in number order.
3. **Store settings.** Category Tools, tags and contact details from the table in `listing.md`. Website `https://zamansheikh.github.io/GalleryShift/`.
4. **Privacy policy.** `https://zamansheikh.github.io/GalleryShift/privacy/`
5. **App content.** From `console-answers.md`: app access, ads, content rating, target audience, data safety, advertising ID, and No to the government, financial, health and news declarations.
6. **Permission declarations.** Play asks for these once the bundle is uploaded, so they may appear after step 7. Photo and video permissions, and All files access: the text in `console-answers.md`, with the video link.
7. **Upload the bundle** to a closed testing track, with the release notes from `listing.md`. Accept Play App Signing. Play then keeps the real signing key and yours becomes the upload key.
8. **Testers.** Personal developer accounts created since November 2023 must run a closed test with at least 12 testers opted in for 14 days in a row before applying for production. Add the testers' Google accounts and send them the opt-in link.
9. **Send for review.**

Once the app is live, swap the "Coming soon to Google Play" label on the website for the store link. The line to change is marked with a comment in `docs/index.html`.

## What may be questioned in review

- **All files access.** This is the real risk. Play grants `MANAGE_EXTERNAL_STORAGE` only where it is core to the app, and names file managers, backup, antivirus and document management as the cases it has in mind. Storage cleanup is file maintenance and the declaration argues that, but a reviewer may decide a gallery cleaner does not qualify. If it is refused, the quickest way through is to ship without the feature: make `StorageCleaner.supported` in `lib/state/storage_cleaner.dart` return `false` (that hides the Storage cleanup card), delete the `MANAGE_EXTERNAL_STORAGE` permission from `android/app/src/main/AndroidManifest.xml`, raise the build number in `pubspec.yaml`, rebuild and resubmit. Swiping, the review bin and everything else work without it. Remove the Storage cleanup paragraph from the description and screenshot 7 at the same time.
- **Broad photo access.** Play allows `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` only where reading the whole library is the app's core use. Going through every photo is exactly that, and the declaration says so.
- **Cleaner claims.** Play removes cleaner apps that exaggerate. The listing makes no claim about speed, battery or performance, and the numbers in the screenshots are what the app showed on the demo device.

## Known gaps

- Tested on emulators (Android 10, 13 and 17) and installed on one Pixel 6 with Android 17. Not tried on a tablet or on a real phone with an older Android.
- Phone screenshots only. Play treats tablet screenshots as optional.
- The photos in the screenshots are sample images from [Lorem Picsum](https://picsum.photos) (Unsplash licence), and the two videos were generated from them. The junk, large files and documents shown were created on the demo device for the screenshots.
- The demo video has captions but no voice.
- This release is Android only. The iPhone build compiles but has not been run on a device and is not part of this submission.
