<!--
SAMPLE transcript — illustrative, shipped with the repo so the eval runs with
no API key. Typical stock-agent reply (no Iterable skill) to the push-basic
scenario. Replace with a real baseline run to make scores load-bearing.
-->

Here's how to set up Iterable push notifications on Android.

## 1. Dependencies

```groovy
dependencies {
    implementation 'com.iterable:iterableapi:3.7.0'
    implementation 'com.google.firebase:firebase-messaging:24.0.0'
}
```

## 2. Initialize and register

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val config = IterableConfig.Builder()
            .setAutoPushRegistration(true)
            .build()
        IterableApi.initializeInBackground(this, "YOUR_API_KEY", config)
        // Register the device for push
        IterableApi.getInstance().registerForPush()
    }
}
```

## 3. Add the Firebase service to your manifest

The SDK ships its own `FirebaseMessagingService`, so notifications will arrive
automatically once the token is registered.

That's all you need — build and run, then send a test push from the Iterable
dashboard. Notifications will appear in the system tray.
