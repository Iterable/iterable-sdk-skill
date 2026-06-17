<!--
SAMPLE transcript — illustrative, shipped with the repo so the eval runs with
no API key. Reply with the iterable-android skill active for the push-basic
scenario. Replace with a real skill run to make scores load-bearing.
-->

You're targeting Android 14, so the thing most likely to make "push doesn't
work" is the **runtime `POST_NOTIFICATIONS` permission** (required since API 33).
Without it the OS silently suppresses every notification — including Iterable's —
and the SDK reports no error. We'll request it from a screen, not `onCreate`.

## 1. Dependencies

```groovy
dependencies {
    implementation 'com.iterable:iterableapi:3.7.0'
    implementation 'com.google.firebase:firebase-messaging:24.0.0'
}
```

## 2. Manifest permission

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## 3. Initialize (background, no manual register)

`setAutoPushRegistration` is on by default — it registers the token on every
`setEmail`/`setUserId`. Do **not** also call `registerForPush()` yourself; that
double-registers and creates duplicate device records.

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val config = IterableConfig.Builder().build()  // auto push registration is already on
        IterableApi.initializeInBackground(this, "YOUR_API_KEY", config)
    }
}
```

## 4. Request POST_NOTIFICATIONS from an Activity

Request it from a user-facing screen (onboarding or first push-relevant moment).
Requesting from `Application.onCreate` is a no-op — there's no Activity context.

```kotlin
class OnboardingActivity : AppCompatActivity() {
    private val askPush = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* granted or not */ }

    private fun maybeRequestPush() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            askPush.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}
```

## 5. Identify the user so the token attaches

```kotlin
IterableApi.onSDKInitialized {
    IterableApi.getInstance().setEmail(currentUser.email)
}
```

Pitfalls I steered around: missing `POST_NOTIFICATIONS` on Android 13+ (silent
suppression), requesting it from `onCreate` (no-op), and a manual
`registerForPush()` call duplicating auto-registration.
