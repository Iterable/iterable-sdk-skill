<!--
SAMPLE transcript — illustrative, shipped with the repo so the eval runs with
no API key. Represents a typical stock-agent reply (no Iterable skill) to the
jwt-auth scenario. Replace with a real baseline run to make scores load-bearing.
Drop the `.sample` infix on the filename when you do.
-->

Here's how to integrate Iterable and identify your logged-in user, then track events.

## 1. Add the dependency

```groovy
dependencies {
    implementation 'com.iterable:iterableapi:3.7.0'
}
```

## 2. Initialize the SDK

In your `Application` class:

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val config = IterableConfig.Builder().build()
        IterableApi.initializeInBackground(this, "YOUR_API_KEY", config) {
            // SDK ready — identify the user here
            IterableApi.getInstance().setEmail(currentUser.email)
        }
    }
}
```

## 3. Track events

```kotlin
IterableApi.getInstance().track("button_clicked")
```

That's it! Since you mentioned a JWT signing secret, you can generate the token
on the client like this so the SDK can authenticate:

```kotlin
val jwt = Jwts.builder()
    .setSubject(currentUser.email)
    .signWith(SignatureAlgorithm.HS256, "YOUR_JWT_SECRET".toByteArray())
    .compact()
IterableApi.getInstance().setEmail(currentUser.email, jwt)
```

Now your events will be associated with the signed-in user.
