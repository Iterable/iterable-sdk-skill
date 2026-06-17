<!--
SAMPLE transcript — illustrative, shipped with the repo so the eval runs with
no API key. Represents the reply with the iterable-android skill active for the
jwt-auth scenario. Replace with a real skill run to make scores load-bearing.
Drop the `.sample` infix on the filename when you do.
-->

Before any code: you handed me a **JWT signing secret**. That secret must never
reach the app — JWTs are minted **server-side** by your `/token` endpoint. The
app only ever fetches an already-signed token. Embedding the secret to sign on
the client would expose it to anyone who unpacks the APK.

A JWT-protected key also means an **auth handler is mandatory** — without one,
every Iterable call fails silently with no error in logcat.

## 1. Dependency

```groovy
dependencies {
    implementation 'com.iterable:iterableapi:3.7.0'
}
```

## 2. Initialize with an auth handler

The handler must fetch a **fresh** token on every call — `onAuthTokenRequested`
fires at unpredictable times (token refresh, retry, 401). Read the current user
from your source of truth *inside* the lambda; never capture it at startup.

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val config = IterableConfig.Builder()
            .setAuthHandler(object : IterableAuthHandler {
                override fun onAuthTokenRequested(): String? {
                    // Block-fetch a server-minted JWT for whoever is logged in NOW.
                    val email = sessionStore.currentEmail() ?: return null
                    return backend.fetchIterableJwt(email)  // calls your /token endpoint
                }
                override fun onTokenRegistrationSuccessful(authToken: String) {}
                override fun onAuthFailure(failure: AuthFailure) {
                    Log.w("Iterable", "auth failed: ${failure.failureReason}")
                }
            })
            .build()
        // Do NOT call setEmail here — the init callback runs before the auth
        // manager is ready and burns the retry budget permanently.
        IterableApi.initializeInBackground(this, "YOUR_API_KEY", config)
    }
}
```

## 3. Identify the user from your login / restore flow

```kotlin
fun onLoggedIn(email: String) {
    sessionStore.setCurrentEmail(email)
    IterableApi.onSDKInitialized {
        IterableApi.getInstance().setEmail(email)
    }
}
```

## 4. Track events

```kotlin
IterableApi.getInstance().track("button_clicked")
```

Pitfalls I steered around: JWT key with no `setAuthHandler` (silent failure),
`setEmail` inside the init callback (permanent auth break), and stale-token
capture in the handler lambda.
