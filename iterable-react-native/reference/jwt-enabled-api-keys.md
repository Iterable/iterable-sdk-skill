---
slug: jwt-enabled-api-keys
feature: jwt-authentication
archetype: prerequisite
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: JWT-Enabled API Keys
source_url: https://support.iterable.com/hc/articles/360050801231
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/api/jwt-enabled-api-keys/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: 27e742891fb5f2f842cb0ecfbe403aa9ee5bbbab
fetched_at: 2026-09-17T15:31:59.465Z
summary: Iterable's API supports authentication with JSON Web Token
  (JWT)-enabled API keys.
---
# JWT-Enabled API Keys

Iterable's API supports authentication with JSON Web Token (JWT)-enabled API
keys.

To authenticate with a JWT-enabled API key, an HTTP request to Iterable's API
must include an authorization header (Bearer schema) whose value is a valid JSON
Web Token. This token is an HMAC SHA256-signed string whose payload includes
(among other things) the email or user ID of the specific Iterable user profile
to whose data it provides access. With a missing, invalid or expired JWT, an API
call made with a JWT-enabled API key will fail with a 401 HTTP response code.

Iterable does not create JSON Web Tokens for you. You must generate them on your
server for each of your users individually, and fetch them when necessary.

> [!NOTE]
> To learn more about JSON Web Tokens, visit [jwt.io](https://jwt.io).

Iterable's iOS, Android and React Native SDKs include built-in support for
JWT-enabled API keys. In your mobile application code, you'll need to implement
a specific callback for the SDK to trigger when it needs a new JWT (for example,
when you identify a user by calling `setEmail` or `setUserId`, or prior to the
current token's expiration). The callback should fetch a user-specific JWT from
your server (or locate one it has already retrieved) and return it as a string.
The SDK then uses the JWT to authenticate subsequent API requests.

## Creating JWT-enabled API keys in Iterable

To learn how to create API keys that require JWT authentication, read 
[API Keys](https://support.iterable.com/hc/articles/360043464871).

## Generating JWTs 

> [!WARNING]
> Iterable doesn't generate JWTs for you. Generate them on your server and provide a way
> for mobile apps to query them for individual users as needed.

A JWT is a string composed of a `<Header>`, `<Payload>` and `<Signature>`—each of
which is base64url-encoded (with trailing `=` removed, after the encoding)—joined
by periods:

```
base64urlencode(<Header>) + "." + base64urlencode(<Payload>) + "." + base64urlencode(<Signature>)
```

`<Header>`, `<Payload>` and `<Signature>` are defined as follows:

- `<Header>`

  ```json
  {
    "alg": "HS256",
    "typ": "JWT"
  }
  ```

- `<Payload>`

  ```json
  { 
    "email": "<email>", 
    "userId": "<userId>", 
    "iat": <Unix Epoch time when token was issued>, 
    "exp": <Unix Epoch time when token expires> 
  }
  ```

  This value must include either an `email` or a `userId` (but not both), `iat`
  ("issued at") and `exp` ("expiration time"—no more than one year/31536000
  seconds after `iat`).
  
  :::tip NOTE 
  `exp` and `iat` values must be a number (integer), not a string. 
  :::

- `<Signature>`

  An HMAC SHA256-encoding of the base64url-encoded `<Header>` and
  base64url-encoded `<Payload>`, joined by a period:

  ```
  HMAC-SHA256(shared_secret, base64urlencode(<Header>) + "." + base64urlencode(<Payload>))
  ```

  When performing the base64url encoding of the `<Header>` and `<Payload>`,
  remove any trailing `=` characters. For the HMAC SHA256 operation, use the
  shared secret associated with the [API key](#creating-jwt-enabled-api-keys-in-iterable) 
  included in the request.

### Sample JWT

Consider the following payload:

```json
{ 
  "email": "test@iterable.com", 
  "iat": 1599693218, 
  "exp": 1599693219 
}
```

For secret `2EB6A2F34691492F81A819AEDA32427F`, this payload's JWT is:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6InRlc3RAaXRlcmFibGUuY29tIiwiaWF0IjoxNTk5NjkzMjE4LCJleHAiOjE1OTk2OTMyMTl9.eDbexB7CnK2jGsXvHfYENrCEkblrLKxgMNbmlfJHXUA
```

To decode this JWT or verify its signature, visit [jwt.io](https://jwt.io).

### Creating JWTs on your server

Iterable does not create JSON Web Tokens for you. Instead, you must create them
on your server and provide a way for applications to query them on a user-by-user
basis.

For example, when a user signs in to your mobile app, it may be reasonable to
include a JWT in the response payload for the login operation. Alternatively, you
can fetch a JWT when Iterable's SDK calls the [auth token requested callback](#defining-the-auth-token-requested-callback) 
(for which you provide the code).

> [!NOTE]
> For a mobile app to use a JWT-enabled API key, it must provide an implementation
> of the [auth token requested callback](#defining-the-auth-token-requested-callback), 
> which provides the JWT to the SDK. The callback can either fetch the JWT from
> your server or return one that has already been retrieved.

### JWT sample code and SDKs

For sample code that demonstrates how to generate JSON Web Tokens, read 
[Sample Python code for JWT generation](#sample-python-code-for-jwt-generation)
and [Sample Java code for JWT generation](#sample-java-code-for-jwt-generation).
Additionally, take a look at the SDKs (for various languages) listed on [jwt.io](https://jwt.io).

## Calling Iterable's API with JWT-enabled API keys

To authenticate an Iterable API call with a JWT-enabled API key, set an HTTP
`Authorization` header (Bearer schema) with a valid, non-expired JWT as its 
value.

The email address or user ID used in the request should match the one found in 
the JWT. If you are calling the `POST /api/users/merge` endpoint, use a JWT for 
the email or user ID of the destination user.

Iterable's mobile SDKs [automatically set this header](#using-iterable-s-mobile-sdks-with-jwt-enabled-api-keys), 
but the following example demonstrates how to construct such a request manually 
(with curl, querying Iterable's USDC-based API):

```
curl -i \
-H "Api-Key: <YOUR_API_KEY>" \
-H "Authorization: Bearer <USER_JWT>" \
https://api.iterable.com/api/inApp/getMessages\?email\=user%40example.com\&count\=100\&platform\=iOS\&SDKVersion\=None
```

## Using Iterable's mobile SDKs with JWT-enabled API keys

To use a JWT-enabled API key in your mobile apps:

- Install JWT-enabled versions of Iterable's mobile SDKs:

  - [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152), 
    version [6.2.12+](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.2.12).

  - [Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712),
    version [3.2.7+](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.2.7)

  - [Iterable's React Native SDK](https://github.com/Iterable/react-native-sdk)
    version [2.2.0+](https://github.com/Iterable/react-native-sdk/releases/tag/2.2.0)

- On `IterableConfig`, provide a [callback](#defining-the-auth-token-requested-callback) 
  for the SDK to trigger whenever it needs a new JWT (for example, when you
  identify a new user or an existing token is ready to expire).

- In the callback, fetch (from your server) a JWT for the app's current user and
  provide it to the SDK (see [below](#defining-the-auth-token-requested-callback).
  If you've already fetched a JWT for the current user (for example, when they
  signed in to your app), you can return that one.

- The SDK will attach the JWT to subsequent API calls.

- Make sure to initialize Iterable's SDK with your project's API key, as usual.

### Defining the auth token requested callback

To learn how to implement an auth token refresh handler in your mobile app code,
see the following docs:

- [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152#step-6-6-handle-jwt-enabled-api-keys)
- [Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712#step-5-6-handle-jwt-enabled-api-keys)
- [Installing Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132#example-sdk-configuration)

### When do Iterable's mobile SDKs trigger the auth token requested callback?

Iterable's mobile SDKs trigger the auth token requested callback when:

- You call `setEmail` or `setUserId` to identify the app's current user (unless
  you pass a prefetched auth token directly to these methods — which
  can be useful to avoid certain race conditions).

- You call `updateEmail` to update the current user's email address (again, unless
  you pass a token directly to this method).

- There remains only one minute until the app's current JWT expires. To configure
  this time period, set `expiringAuthTokenRefreshPeriod`, in seconds, on
  `IterableConfig`.

- The SDK makes an API call and receives a 401 response with an `InvalidJwtPayload`
  error code. If using the new JWT yields another 401 with a `InvalidJwtPayload`
  error code, the SDK will not trigger a second consecutive auth token request
  until you kill the app or call `setEmail` or `setUserId`.
  
> [!NOTE]
> - There is currently no way to manually trigger the auth token requested callback.
>   If you have a use case for this (e.g., a network failure on your server), we
>   recommend implementing custom retry logic when fetching the JWT token.
> - If your app doesn't use JWT-enabled API keys, don't implement the auth token
>   requested callback.

### Sample 401 response with an `InvalidJwtPayload` error code

```
HTTP/2 401
date: Tue, 22 Sep 2020 22:54:18 GMT
content-type: application/json
content-length: 99
vary: Origin
request-time: 7
server: iterable-ingress b48a

{"msg":"JWT token is expired","code":"InvalidJwtPayload","params":{"endpoint":"/api/events/track"}}
```

### Updating existing mobile apps to use JWT-enabled API keys

To update existing mobile apps to use JWT-enabled API keys, follow these
instructions:

1. In your Iterable project, [create a JWT-enabled Mobile API key](#creating-jwt-enabled-api-keys-in-iterable).

2. On your server, set up a way to [generate JWTs for individual users](#generating-jwts). 
   To create them, use the shared secret associated with the API key created in
   step 1.

3. Create a web service your mobile apps can query to fetch JWTs for specific
   users.

4. In your mobile apps, install versions of Iterable's iOS and Android SDKs that
   support JWT-enabled API keys.

5. In the code for your mobile apps, when it makes sense to do so, fetch the JWT
   for the current user from your server. You may want to do this when a user signs
   in to your app, or as part of the [auth token requested callback](#defining-the-auth-token-requested-callback).
   If necessary, you can manually prefetch an auth token and pass it to the 
   `setEmail`, `setUserId`, and `updateUser` methods.

6. Use your updated application code to create and release new versions of your
   mobile apps. 

7. Monitor the usage of these new versions of your apps, and the older
   versions for which JWT authentication is not in use. 

8. When a high enough percentage of your customers are using the JWT-enabled
   versions of your apps, contact your customer success manager to talk about 
   downgrading or disabling old, non-JWT API keys.

## Sample Python code for JWT generation

> [!WARNING]
> The following code is for demonstration purposes only. It may contain bugs, and
> it should be adapted to your particular scenario and thoroughly tested before
> being used in production.

```python
import base64
import json
import hmac
import hashlib
 
encoding = "utf-8"
secret = "<API_KEY_SHARED_SECRET>".encode(encoding)
iat = 1600116847
exp = 1600203247
    
jwt_header = json.dumps(
   { "alg": "HS256", "typ": "JWT" }, separators=(",", ":")
).encode(encoding)
 
jwt_payload = json.dumps(
   {"userId": "<USER_ID>", "iat": iat, "exp": exp}, separators=(",", ":")
).encode(encoding)
 
encoded_header_bytes = base64.urlsafe_b64encode(jwt_header).replace(b"=", b"")
encoded_payload_bytes = base64.urlsafe_b64encode(jwt_payload).replace(b"=", b"")
 
jwt_signature = hmac.digest(
   key=secret,
   msg=b".".join([encoded_header_bytes, encoded_payload_bytes]),
   digest=hashlib.sha256
)
 
encoded_signature_bytes = base64.urlsafe_b64encode(jwt_signature).replace(b"=", b"")
 
jwt_returned = (
   f"{str(encoded_header_bytes, encoding)}" +
   f".{str(encoded_payload_bytes, encoding)}" +
   f".{str(encoded_signature_bytes, encoding)}"
)
 
# Verify this token at https://jwt.io/#debugger-io
print(jwt_returned)
```

## Sample Java code for JWT generation

> [!WARNING]
> The following code is for demonstration purposes only. It may contain bugs, and
> it should be adapted to your particular scenario and thoroughly tested before
> being used in production.

`IterableJWTGenerator.java` (generates a JWT):

```java
package com.iterable;
 
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.Base64.Encoder;
 
/**
* Utility class to generate JWTs for use with the Iterable API
*
* @author engineering@iterable.com
*/
public class IterableJwtGenerator {
   static Encoder encoder = Base64.getUrlEncoder().withoutPadding();
  
   private static final String algorithm = "HmacSHA256";
 
   // Iterable enforces a 1-year maximum token lifetime
   private static final Duration maxTokenLifetime = Duration.ofDays(365);
 
   private static long millisToSeconds(long millis) {
       return millis / 1000;
   }
 
   private static final String encodedHeader = encoder.encodeToString(
       "{\"alg\":\"HS256\",\"typ\":\"JWT\"}".getBytes(StandardCharsets.UTF_8)
   );
 
   /**
    * Generates a JWT from the provided secret, header, and payload. Does not
    * validate the header or payload.
    *
    * @param secret  Your organization's shared secret with Iterable
    * @param payload The JSON payload
    *
    * @return a signed JWT
    */
   public static String generateToken(String secret, String payload) {
       try {
           String encodedPayload = encoder.encodeToString(
               payload.getBytes(StandardCharsets.UTF_8)
           );
           String encodedHeaderAndPayload = encodedHeader + "." + encodedPayload;
 
           // HMAC setup
           Mac hmac = Mac.getInstance(algorithm);
           SecretKeySpec keySpec = new SecretKeySpec(
               secret.getBytes(StandardCharsets.UTF_8), algorithm
           );
           hmac.init(keySpec);
 
           String signature = encoder.encodeToString(
               hmac.doFinal(
                   encodedHeaderAndPayload.getBytes(StandardCharsets.UTF_8)
               )
           );
 
           return encodedHeaderAndPayload + "." + signature;
 
       } catch (Exception e) {
           throw new RuntimeException(e.getMessage());
       }
   }
 
   /**
    * Generates a JWT (issued now, expires after the provided duration).
    *
    * @param secret   Your organization's shared secret with Iterable.
    * @param duration The token's expiration time. Up to one year.
    * @param email    The email to included in the token, or null.
    * @param userId   The userId to include in the token, or null.
    *
    * @return A JWT string
    */
   public static String generateToken(
       String secret, Duration duration, String email, String userId) {
 
       if (duration.compareTo(maxTokenLifetime) > 0)
           throw new IllegalArgumentException(
               "Duration must be one year or less."
           );
 
       if ((userId != null && email != null) || (userId == null && email == null))
           throw new IllegalArgumentException(
               "The token must include a userId or email, but not both."
           );
 
       long now = millisToSeconds(System.currentTimeMillis());
 
       String payload;
       if (userId != null)
           payload = String.format(
               "{ \"userId\": \"%s\", \"iat\": %d, \"exp\": %d }",
               userId, now, now + millisToSeconds(duration.toMillis())
           );
       else
           payload = String.format(
               "{ \"email\": \"%s\", \"iat\": %d, \"exp\": %d }",
               email, now, now + millisToSeconds(duration.toMillis())
           );
 
       return generateToken(secret, payload);
   }
}
```

`Main.java` (shows how to use `IterableJwtGenerator`):

```java
package com.iterable;
 
import java.time.Duration;
 
public class Main {
 
  private static final String secret = "<API_KEY_SHARED_SECRET>";
  private static final String email = "<TEST_EMAIL>";
  private static final String userId = "<TEST_USER_ID>";
  private static final Duration days7 = Duration.ofDays(7);
  private static final Duration days366 = Duration.ofDays(366);
  private static final int issuedAt = 1516239022;
  private static final int expiration = 1516239023;
  private static final String payload = String.format(
     "{ \"email\": \"%s\", \"iat\": %d, \"exp\": %d }",
     email, issuedAt, expiration
  );
 
  public static void main(String[] args) {
     // Valid (email but no userId)
     System.out.println(
        IterableJwtGenerator.generateToken(secret, days7, email, null)
     );
 
     // Valid (userId but no email)
     System.out.println(
        IterableJwtGenerator.generateToken(secret, days7, null, userId)
     );
 
     // Invalid (no email, no userId)
     try {
        System.out.println(
           IterableJwtGenerator.generateToken(secret, days7, null, null)
        );
     } catch (IllegalArgumentException e) {
        System.out.println(e.getMessage());
     }
 
     // Invalid (email and userId)
     try {
        System.out.println(
           IterableJwtGenerator.generateToken(secret, days7, email, userId)
       );
     } catch (IllegalArgumentException e) {
        System.out.println(e.getMessage());
     }
 
     // Invalid (duration is more than a year)
     try {
        IterableJwtGenerator.generateToken(secret, days366, email, null);
     } catch (IllegalArgumentException e) {
        System.out.println(e.getMessage());
     }
 
     // Valid (passing in custom JSON, which the method does not validate)
     System.out.println(IterableJwtGenerator.generateToken(secret, payload));
  }
}
```
