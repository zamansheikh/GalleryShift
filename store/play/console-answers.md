# Play Console forms

Answers for the forms under Policy, App content, in the order Play Console lists them. Every answer here was checked against the 1.0.0 bundle. Play rewords these forms from time to time: where a question differs, answer from the facts in the first table.

## Facts the answers rest on

| | |
|---|---|
| Sends data off the phone | No. The bundle has no `INTERNET` permission |
| Account or sign-in | None |
| Ads, analytics, crash reporting | None |
| Advertising ID | Not used. No `AD_ID` permission in the bundle |
| In-app purchases | None |
| Data kept on the phone | Keep and delete decisions, totals, a few settings. Private app storage, excluded from backup |
| Users can talk to or share with each other | No |

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |

That ends the form. Reading photos and files on the phone is not "collection" in Play's sense: collection means data leaving the device, and nothing does. The listing will then show "No data collected" and "No data shared with third parties".

## Content rating questionnaire

| Question | Answer |
|---|---|
| Email address | Your contact email |
| Category | **Utility, Productivity, Communication, or Other** |
| Violence, blood, frightening content | No |
| Sexuality or nudity | No |
| Profanity or crude humour | No |
| Drugs, alcohol or tobacco | No |
| Gambling, simulated or real | No |
| Users can interact or exchange content | No |
| Shares the user's location with others | No |
| Allows purchases of digital goods | No |

The app shows the user's own photos and has no content of its own. Expect a rating of Everyone, or PEGI 3.

## Target audience

| Question | Answer |
|---|---|
| Target age groups | **13-15, 16-17, 18 and over** |
| Could the store listing unintentionally appeal to children? | No |

Leave the under-13 groups unticked. Ticking them brings in the Families policy and its extra requirements, which this app has no reason to take on.

## Ads

| Question | Answer |
|---|---|
| Does your app contain ads? | **No** |

## Advertising ID

| Question | Answer |
|---|---|
| Does your app use advertising ID? | **No** |

## App access

| Question | Answer |
|---|---|
| Is any part of the app restricted (login, subscription, location)? | **All functionality is available without special access** |

## Photo and video permissions declaration

Play asks for this because the bundle requests `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO`. It may only appear after the bundle is uploaded.

Play Console shows the error "All developers requesting access to the photo and video permissions are required to tell Google Play about the core functionality of their app" until this is filled in. The form has one box per permission, 250 characters each.

`READ_MEDIA_IMAGES` (242 of 250 characters):

```
GalleryShift is a gallery cleanup app. Its core feature shows every photo in the user's library, one at a time, so they can swipe to keep or delete each one. It needs frequent access to the whole library; a photo picker cannot serve this use.
```

`READ_MEDIA_VIDEO` (242 of 250 characters):

```
GalleryShift is a gallery cleanup app. Its core feature plays every video in the user's library, one at a time, so they can swipe to keep or delete each one. It needs frequent access to the whole library; a photo picker cannot serve this use.
```

If the form allows more room:

```
GalleryShift is a gallery cleanup app. Its one core function is to show the user every photo and video in their library, one at a time, so they can swipe right to keep or left to delete, then delete the rejected ones in a batch. The app builds its decks from the whole library (all photos, by month, screenshots, videos, on this day) and tracks progress across all of it, so it needs persistent, broad access to images and videos. The system photo picker cannot serve this: the user would have to hand-pick thousands of photos one by one before they could start, which is the very task the app exists to remove. Media is only read on the device. The app has no internet permission.
```

## All files access declaration

Play asks for this because the bundle requests `MANAGE_EXTERNAL_STORAGE`. Until it is filled in, Play Console shows the error "This release includes permissions that haven't been declared in Play Console" and links to Sensitive app permissions. This is the declaration most likely to be questioned: see "What may be questioned in review" in `README.md`.

The form has four fields, as seen in Play Console on 12 October 2026.

**All files access** (describe one feature that needs a permitted use; 464 of 500 characters):

```
Storage cleanup, a file management feature. It scans the phone's shared storage to find junk files (leftovers from the system trash, used APK installers, temp files, abandoned partial downloads, thumbnail caches), empty folders, large files and old documents in every folder. The user reviews each category, can open a file to check it, and chooses what to delete. Nothing is removed without confirmation. Access is requested only when the user opens this feature.
```

**Usage** (tick boxes): tick **Core functionality** only. Leave Personalization, Security or fraud prevention, Analytics, and Ads or monetization empty.

**Technical reason** (why the Storage Access Framework or MediaStore will not do; 468 of 500 characters):

```
The files this feature cleans are not media and are often hidden: trash leftovers, .apk, .log and .tmp files, thumbnail caches and empty folders, spread across all of shared storage. MediaStore does not return them. The Storage Access Framework cannot serve either: on Android 11+ it cannot grant the storage root or the Download folder, and the user would have to pick every folder by hand. The app never reads other apps' private data and has no internet permission.
```

**Video instructions**: `https://www.youtube.com/watch?v=lBYsHyRAoHY`, which is `all-files-access-demo.mp4` uploaded to the Silifton channel. Play recommends 30 seconds or shorter; this one runs 71 seconds.

## Government, financial, health and news declarations

| Question | Answer |
|---|---|
| Is this a government app? | No |
| Financial features | My app doesn't provide any financial features |
| Health features | My app doesn't have any health features |
| Is this a news app? | No |
