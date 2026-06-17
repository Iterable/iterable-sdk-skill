---
slug: updating-user-profiles
feature: user-profiles
archetype: identity
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: Updating User Profiles
source_url: https://support.iterable.com/hc/articles/360035402611
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/managing-user-profiles/updating-user-profiles/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 3cca4ebdd1ee9da638428e3ded39de472202fd94
fetched_at: 2026-05-25T15:11:47.716Z
polished_at: 2026-06-05T13:59:18.318Z
layer: a
snippets:
  - index: 0
    lang: swift
    hash: 98edcca734b9
    line_count: 28
  - index: 1
    lang: objectivec
    hash: f643548616dc
    line_count: 30
  - index: 2
    lang: java
    hash: af02941d202c
    line_count: 16
  - index: 3
    lang: handlebars
    hash: 36130f23171c
    line_count: 1
  - index: 4
    lang: json
    hash: ea4da7f4ae5d
    line_count: 4
  - index: 5
    lang: json
    hash: 73fe86262683
    line_count: 4
  - index: 6
    lang: json
    hash: 73fe86262683
    line_count: 4
  - index: 7
    lang: json
    hash: 3e53f4645bf8
    line_count: 6
  - index: 8
    lang: swift
    hash: 0eb671afc60f
    line_count: 20
  - index: 9
    lang: objectivec
    hash: 874ed71683e9
    line_count: 25
  - index: 10
    lang: java
    hash: a2365a08fdc4
    line_count: 17
summary: "A user's Iterable profile contains descriptive information about them:
  demographic info, preferences, etc. You can use this data to create dynamic
  lists and customize the messages you send (by referencing user profile data
  with [Handlebars](https://support.iterable.com/hc/articles/35601631606036))."
---
# Updating User Profiles

A user's Iterable profile contains descriptive information about them:
demographic info, preferences, etc. You can use this data to create dynamic
lists and customize the messages you send (by referencing user profile data with
[Handlebars](https://support.iterable.com/hc/articles/35601631606036)).

## Limitations

User profiles have a soft limit of 1,000 fields. If you think you'll need more
fields, talk to your Iterable Customer Success Manager.

## How to make the updateUser call

Here's some sample code that makes an `updateUser` call:

_Swift_

```swift
// The IterableAPI.updateUser(...) can be called anywhere the SDK is accessible
// myFunc() demonstrates this usage
import IterableSDK

func myFunc() {
    let dataField: [String: Any] = [
        "Address": [
            "Street1": "123 Main St",
            "Street2": "Apt 1",
            "City": "Iter-a-ville",
            "State": "CA",
            "Zip": "90210"
        ]
    ]
    
    IterableAPI.updateUser(dataField,
                           mergeNestedObjects: false,
                           onSuccess: myUserUpdateSuccessHandler,
                           onFailure: myUserUpdateFailureHandler)
}

func myUserUpdateSuccessHandler(data: [AnyHashable: Any]?) -> () {
    print("Successfully sent user update request to Iterable")
}

func myUserUpdateFailureHandler(reason: String?, data: Data?) -> () {
    print("Failure sending user update request to Iterable")
}
```

_Objective-C_

```objectivec
// The [IterableAPI updateUser:...] can be called anywhere the SDK is accessible
// myFunc demonstrates this usage
@import IterableSDK;

typedef void (^successHandler)(NSDictionary * _Nullable);
typedef void (^failureHandler)(NSString * _Nullable, NSData * _Nullable);

- (void)myFunc {
    NSDictionary<NSString *, id> *data = @{
        @"Address": @{ @"Street1": @"123 Main St",
                       @"Street2": @"Apt 1",
                       @"City": @"Iter-a-ville",
                       @"State": @"CA",
                       @"Zip": @"90210"
        }
    };
    
    [IterableAPI updateUser:data
         mergeNestedObjects:NO
                  onSuccess:myUserUpdateSuccessHandler
                  onFailure:myUserUpdateFailureHandler];
}

successHandler myUserUpdateSuccessHandler = ^(NSDictionary * _Nullable data) {
    NSLog(@"Successfully sent user update request to Iterable");
};

failureHandler myUserUpdateFailureHandler = ^(NSString * _Nullable reason, NSData * _Nullable data) {
    NSLog(@"Failure sending user update request to Iterable");
};
```

_Java_

```java
JSONObject address = new JSONObject();
JSONObject datafields = new JSONObject();

try {
    address.put("Street1", "123 Main St");
    address.put("Street2", "Apt 1");
    address.put("City", "Iter-a-ville");
    address.put("State", "CA");
    address.put("Zip", "90210");

    datafields.put("dataFields", address);
} catch (JSONException e) {
    e.printStackTrace();
}

IterableApi.getInstance().updateUser(datafields);
```

Now, in your messages, you can reference the user's `City` (or any other field) 
with [Handlebars](https://support.iterable.com/hc/articles/35601631606036), like this:

```handlebars
{{Address.City}}
```

### How `mergeNestedObjects` works

The `mergeNestedObjects` parameter determines whether Iterable should merge 
fields included in an `updateUser` request with analogous objects on the user's 
profile, or overwrite that data.

`mergeNestedObjects` only works for **one level of nesting** within objects. It 
does **not** work recursively for deeper nested objects, and it does not merge 
arrays.

For objects nested more than one level deep, `mergeNestedObjects` will 
**overwrite** the entire nested structure, not merge it. You must include all 
existing data along with your updates to preserve deeper nested values.

`mergeNestedObjects` defaults to `false`.

For example, consider a user profile that includes the following address object:

```json
"address": {
    "street": "123 Main St",
    "city": "San Francisco"
}
```

Then, assume that an `updateUser` call includes a similar object:

```json
"address": {
    "state": "CA",
    "zipCode": "94105"
}
```

If `updateUser` sets `mergeNestedObjects` to `false` (the default value), the 
resulting user profile value is:

```json
"address": {
    "state": "CA",
    "zipCode": "94105"
}
```

However, if `updateUser` sets `mergeNestedObjects` to `true`, the resulting
user profile value is:

```json
"address": {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "zipCode": "94105"
}
```

## When to make the updateUser call

Call `updateUser` when a user has:

- Updated their personal information.
- Completed a key step in an onboarding or sales process. For example, you might
  want to set `completedOnboarding` to `true`, or assign a value to a field that's
  useful for segmentation (setting `testGroup` to `testGroupA` or something
  similar).
- Completed a key step in your onboarding, sales or retargeting process. For
  example, you may want to add `"completedOnboarding": true` or `"testGroup": "A"` 
  to the user profile for later segmentation, splitting the users down different 
  journeys or analyzing later for test comparisons.

## Tracking anonymous users

To track anonymous users in Iterable, provide a `userId`. If your project uses
`email` as the only unique identifier, then this causes Iterable to generate a
placeholder email for the user—read
[Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956)
for more info).

## Taking a user from anonymous to known

Iterable can convert anonymous users to known users. The example function below
updates the current user's `email` and `userId`. You will likely want to use
this code when your user signs in or self-identifies when signing up.

_Swift_

```swift
let email = "newEmail@example.com"

// The IterableAPI.updateUser(...) can be added to any method within your code. `yourUserIsNowKnownFunction` is just an example
func yourUserIsNowKnownFunction() {
    IterableAPI.updateEmail(email,
                            onSuccess: myUserUpdateSuccessHandler,
                            onFailure: myUserUpdateFailureHandler)
}

func myUserUpdateSuccessHandler(data: [AnyHashable: Any]?) -> () {
    print("Successfully sent user update request to Iterable")
}

func myUserUpdateFailureHandler(reason: String?, data: Data?) -> () {
    print("Failure sending user update request to Iterable")

    IterableAPI.email = email

    IterableAPI.updateUser(dataField, mergeNestedObjects: false)
}
```

_Objective-C_

```objectivec
@import IterableSDK;

typedef void (^successHandler)(NSDictionary * _Nullable);
typedef void (^failureHandler)(NSString * _Nullable, NSData * _Nullable);

NSString *email = @"newEmail@example.com";

// The [IterableAPI updateUser:...] can be added to any method within your code. `yourUserIsNowKnownFunction` is just an example
- (void)yourUserIsNowKnownFunction {
    [IterableAPI updateEmail:email 
        onSuccess:myUserUpdateSuccessHandler 
        onFailure:myUserUpdateFailureHandler];
}

successHandler myUserUpdateSuccessHandler = ^(NSDictionary * _Nullable data) {
    NSLog(@"Successfully sent user update request to Iterable");
};

failureHandler myUserUpdateFailureHandler = ^(NSString * _Nullable reason, NSData * _Nullable data) {
    NSLog(@"Failure sending user update request to Iterable");
    
    IterableAPI.email = email;

    [IterableAPI updateUser:dataField mergeNestedObjects:false];
};
```

_Java_

```java
final String email = "newEmail@example.com";

IterableApi.getInstance().updateEmail(email, new IterableHelper.SuccessHandler() {
    @Override
    public void onSuccess(JSONObject data) {
        System.out.println("sent to Iterable success");

    }
}, new IterableHelper.FailureHandler() {
    @Override
    public void onFailure(String reason, JSONObject data) {
        System.out.println("sent to Iterable failure");
        IterableApi.getInstance().setEmail(email);
        //This assumes your saving your user profile fields in the datafield object locally
        IterableApi.getInstance().updateUser(datafields);
    }
});
```

There is a chance the `updateEmail` call will fail. The most likely reason is
that the user already exists so we should now update the user call directly in
the `onFailure` handler.
