---
url: https://iterable.zendesk.com/hc/articles/360039189931
title: Customizing Mobile Inbox on Android
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/customizing-mobile-inbox-on-android/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 502be69e2212a0540bcaaad80299d4e3936bb656
fetched_at: 2026-05-25T15:11:42.777Z
---
# Customizing Mobile Inbox on Android

A [mobile inbox](https://support.iterable.com/hc/articles/217517406) provides an
app-specific place for users to save in-app messages to read later. 

Iterable's [Android SDK](https://support.iterable.com/hc/articles/360035019712)
includes a default user interface for a mobile inbox, and you can customize it
to match your organization's branding and styles, and to display any necessary
fields. 

This document describes different ways to customize the mobile inbox provided by
Iterable's Android SDK.

## In this article

[[toc]]

## Setting up the mobile inbox

Before customizing your app's mobile inbox, read 
[Setting up Mobile Inbox on Android](https://support.iterable.com/hc/articles/360038744152)
to learn how to set it up and display it.

## Sample app

![Sample app](https://iterable.zendesk.com/hc/article_attachments/360050615391/sample-app.png "Sample app")

To better undersand how to customize your app's mobile inbox, take a look at the
code in the **Inbox Customization** [sample project](https://github.com/Iterable/iterable-android-sdk/tree/master/sample-apps/inbox-customization)
(found in the same GitHub repository as Iterable's Android SDK).

## Customizing the mobile inbox

This section describes how to customize the user interface of the mobile inbox
embedded in your Android mobile app. 

:::tip NOTE
Some customizations require you to create a subclass of `IterableInboxFragment`, 
and others do not.
:::

### Empty state

In an empty mobile inbox, you can display custom text (title and body) to help
orient your users. These values are blank by default, and they'll wrap to
multiple lines if needed. For example:

![Android mobile inbox empty state](https://iterable.zendesk.com/hc/article_attachments/360091087811/android-inbox-empty-state.png "Android mobile inbox empty state")

Use this code to set this text when using the mobile inbox fragment:

_Kotlin_

```kotlin
var bundle = Bundle()
bundle.putString(IterableConstants.NO_MESSAGES_TITLE,"No saved messages")
bundle.putString(IterableConstants.NO_MESSAGES_BODY, "Check again later!")
val fragment: Fragment = Fragment.instantiate(this, IterableInboxFragment::class.java.name, bundle))
```

Use this code to set the text when using the mobile inbox activity:

_Kotlin_

```kotlin
var intent = Intent(this.context,IterableInboxActivity::class.java)
intent.putExtra(IterableConstants.NO_MESSAGES_TITLE, "No saved messages")
intent.putExtra(IterableConstants.NO_MESSAGES_BODY, "Check again later!")
startActivity(intent)
```

_Java_

```java
startActivity(
    new Intent(getApplicationContext(),IterableInboxActivity.class)
        .putExtra(IterableConstants.NO_MESSAGES_TITLE,"No saved messages")
        .putExtra(IterableConstants.NO_MESSAGES_BODY,"Check again later!")
);
```

### Message display style (popup or navigation)

A mobile inbox can display messages as popups directly in the inbox view (the
default) or as standalone activities. To change this setting, either:

- Set an extra for the activity's intent:

    Kotlin:

    ```kotlin
    val intent = Intent(context, IterableInboxActivity::class.java)
    intent.putExtra("inboxMode", InboxMode.ACTIVITY)
    startActivity(intent)
    ```

    Java:

    ```java
    Intent intent = new Intent(getContext(), IterableInboxActivity.class);
    intent.putExtra("inboxMode", InboxMode.ACTIVITY);
    startActivity(intent);
    ```

- Pass constructor parameters to the fragment:

    Kotlin:

    ```kotlin
    val inboxFragment = IterableInboxFragment.newInstance(InboxMode.ACTIVITY, 0)
    ```

    Java:

    ```java
    IterableInboxFragment inboxFragment = IterableInboxFragment.newInstance(InboxMode.ACTIVITY)
    ```

### Activity title

When launching the mobile inbox as an activity, change the title by passing an
`activityTitle` argument in the intent:

Kotlin:

```kotlin
val intent = Intent(context, IterableInboxActivity::class.java)
intent.putExtra("activityTitle", "My Inbox")
startActivity(intent)
```

Java:

```java
Intent intent = new Intent(getContext(), IterableInboxActivity.class);
intent.putExtra("activityTitle", "My Inbox");
startActivity(intent);
```

### Cell layout, colors and font

![Inbox cells with a custom layout](https://iterable.zendesk.com/hc/article_attachments/360050615411/custom-layout.png "Inbox cells with a custom layout")

:::tip TIP
In the [sample app](#sample-app), tap **Inbox with Custom Cell** to see an
example of an inbox that uses custom cells.
:::

To modify the font, color or layout of inbox cells:

1. Copy the [`iterable_inbox_item.xml`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/res/layout/iterable_inbox_item.xml) 
   layout file from [`iterableapi-ui`](https://github.com/Iterable/iterable-android-sdk/tree/master/iterableapi-ui/src/main/res/layout).
   Give it a new name, such as `custom_inbox_item.xml`.

2. In the new file, change the layout, colors and fonts to match your app’s
   styles.

3. Specify this layout ID when launching the activity:

    Kotlin:

    ```kotlin
    val intent = Intent(context, IterableInboxActivity::class.java)
    intent.putExtra("itemLayoutId", R.layout.custom_inbox_item)
    startActivity(intent)
    ```

    Java:

    ```java
    Intent intent = new Intent(getContext(), IterableInboxActivity.class);
    intent.putExtra("itemLayoutId", R.layout.custom_inbox_item);
    startActivity(intent);
    ```

4. Alternatively, create the fragment with custom parameters:

    Kotlin:

    ```kotlin
    val inboxFragment = IterableInboxFragment.newInstance(InboxMode.POPUP, R.layout.custom_inbox_item)
    ```

    Java:

    ```java
    IterableInboxFragment inboxFragment = IterableInboxFragment.newInstance(InboxMode.POPUP, R.layout.custom_inbox_item);
    ```

### Date format and visibility

![Inbox with custom date format](https://iterable.zendesk.com/hc/article_attachments/360050615451/change-date-format.png "Inbox with custom date format")

:::tip TIP
In the [sample app](#sample-app), tap **Change Date Format** to see an
example of an inbox that uses custom cells.
:::

To change the format or visibility of the date field for each message cell,
subclass `IterableInboxFragment` and set a date mapper in `onCreate`. The date 
mapper takes an `IterableInAppMessage` and returns a string representing the 
creation date of the message. If the date field should be blank, return `null`.

Kotlin:

```kotlin
class CustomInboxDateMapperFragment : IterableInboxFragment() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setDateMapper { message ->
            DateUtils.getRelativeTimeSpanString(
                    message.createdAt.time,
                    Date().time,
                    0,
                    DateUtils.FORMAT_ABBREV_ALL
            )
        }
    }
}
```

Java:

```java
public class CustomInboxDateMapperJavaFragment extends IterableInboxFragment implements IterableInboxDateMapper {
    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setDateMapper(this);
    }

    @Nullable
    @Override
    public CharSequence mapMessageToDateString(@NonNull IterableInAppMessage message) {
        return DateUtils.getRelativeTimeSpanString(
                message.getCreatedAt().getTime(),
                new Date().getTime(),
                0,
                DateUtils.FORMAT_ABBREV_ALL
        );
    }
}
```

### Filtering messages

![Inbox with filtered messages](https://iterable.zendesk.com/hc/article_attachments/360050615471/filtering-messages.png "Inbox with filtered messages")

:::tip TIP
In the [sample app](#sample-app), tap **Filter by Message Type** or
**Filter by Message Title** to see an example of an inbox that uses custom
filtering.
:::

To filter which messages are displayed in the mobile inbox, subclass
`IterableInboxFragment` and call `setFilter` in the `onCreate` method. The filter
should take an `IterableInAppMessage` and return a boolean: `true` to show
the message, `false` otherwise. 

`IterableInboxFilter` is an interface that declares a filter method.

Kotlin:

```kotlin
class CustomInboxFilterFragment : IterableInboxFragment() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFilter { message -> message.customPayload?.has("price") == true }
    }
}
```

Kotlin (alternative implementation):

```kotlin
class CustomInboxFilterFragment : IterableInboxFragment(), IterableInboxFilter {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFilter(this)
    }

    override fun filter(message: IterableInAppMessage): Boolean {
        return message.customPayload?.has("price") == true
    }
}
```

Java:

```java
public class CustomInboxFilterFragment extends IterableInboxFragment implements IterableInboxFilter {
    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setFilter(this);
    }

    @Override
    public boolean filter(@NonNull IterableInAppMessage message) {
        JSONObject payload = message.getCustomPayload();
        return payload != null && payload.has("price");
    }
}
```

### Sorting messages

![Inbox with sorted messages](https://iterable.zendesk.com/hc/article_attachments/360050505852/sorting-messages.png "Inbox with sorted messages")

:::tip TIP
In the [sample app](#sample-app), tap **Sort by Title Ascending** or
**Sort by Date Ascending** to see an example of an inbox that changes the way
messages are sorted.
:::

By default, Mobile Inbox sorts messages descending by date. However, it is 
possible to sort the message order in other ways.

To sort the messages in the mobile inbox, subclass `IterableInboxFragment` and
set a comparator in `onCreate`. `IterableInboxComparator` is a standard Java
`Comparator` interface: return a negative integer, zero, or a positive integer 
when the first message is less than, equal to, or greater than the second.

Kotlin:

```kotlin
class CustomInboxComparatorFragment : IterableInboxFragment() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setComparator { message1, message2 ->
            message1.createdAt.compareTo(message2.createdAt) // Sort by creation date ascending
        }
    }
}
```

Kotlin (alternative implementation):

```kotlin
class CustomInboxComparatorFragment : IterableInboxFragment(), IterableInboxComparator {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setComparator(this)
    }

    override fun compare(message1: IterableInAppMessage, message2: IterableInAppMessage): Int {
        return message1.createdAt.compareTo(message2.createdAt)   // Sort by creation date ascending
    }
}
```

```java
public class CustomInboxComparatorJavaFragment extends IterableInboxFragment implements IterableInboxComparator {
    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setComparator(this);
    }

    @Override
    public int compare(@NonNull IterableInAppMessage message1, @NonNull IterableInAppMessage message2) {
        // Sort by creation date ascending
        return message1.getCreatedAt().compareTo(message2.getCreatedAt());
    }
}
```

### Adding fields to the inbox cell

![Inbox items with added fields](https://iterable.zendesk.com/hc/article_attachments/360050505872/adding-fields.png "Inbox items with added fields")

:::tip TIP
In the [sample app](#sample-app), tap **Additional Fields** to see an example of
an inbox that has additional fields on each cell.
:::

To add additional fields to the items displayed in the mobile inbox:

1. Copy the [`iterable_inbox_item.xml`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/res/layout/iterable_inbox_item.xml) 
   layout file from [`iterableapi-ui`](https://github.com/Iterable/iterable-android-sdk/tree/master/iterableapi-ui/src/main/res/layout).
   Give it a new name, such as `custom_inbox_item.xml`.

2. Subclass `IterableInboxFragment` and set the adapter extension. The methods 
   are similar to the ones in a `RecyclerView` adapter, but instead of a
   `RecyclerView.ViewHolder` class, the extension is a plain Java class. See
   [`IterableInboxAdapterExtension`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/java/com/iterable/iterableapi/ui/inbox/IterableInboxAdapterExtension.java)
   for more details.

    - Return your custom layout in `getLayoutForViewType`.
    - Create a static inner plain Java class for a `ViewHolderExtension`.
    - Add fields referencing the new views in your layout.
    - Create a constructor with calls to `findViewById` to populate those fields.
    - In `createViewHolderExtension`, call your view holder extension’s
    constructor and return the result.
    - In `onBindViewHolder`, update the UI for the given inbox message using the
    standard Iterable ViewHolder (holding references to the standard fields, like
    `title`, `subtitle` and others) and your extension object (holding references
    to your custom views).

For a reference implementation, see the example in the next section.

### Multiple cell layouts

![Inbox with multiple cell types](https://iterable.zendesk.com/hc/article_attachments/360050505892/multiple-cell-layouts.png "Inbox with multiple cell types")

:::tip TIP
In the [sample app](#sample-app), tap **Multiple Cell Types** to see an example 
of an inbox that uses multiple cell types.
:::

To display different inbox items with different interfaces, follow these steps:

1. Copy the [`iterable_inbox_item.xml`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/res/layout/iterable_inbox_item.xml) 
   layout file from [`iterableapi-ui`](https://github.com/Iterable/iterable-android-sdk/tree/master/iterableapi-ui/src/main/res/layout).
   Give it a new name, such as `custom_inbox_item.xml`.

2. Subclass `IterableInboxFragment` and set the adapter extension. See
   [`IterableInboxAdapterExtension`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/java/com/iterable/iterableapi/ui/inbox/IterableInboxAdapterExtension.java)
   for more details.

3. Create integer constants for every type of cell you’re planning to have in
   your custom inbox.

4. Return those constants in `getItemViewType` by checking the inbox message
   attributes.

5. The same constants will then be passed to `getLayoutForViewType`. Use them to
   return different layouts based on the view type.

Kotlin:

```kotlin
class CustomInboxFieldsFragment : IterableInboxFragment(), IterableInboxAdapterExtension<CustomInboxFieldsFragment.ViewHolder> {
    val ITEM_TYPE_DEFAULT = 1
    val ITEM_TYPE_SALE = 2

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setAdapterExtension(this)
    }

    override fun getItemViewType(message: IterableInAppMessage): Int {
        if (message.customPayload?.has("price") == true) {
            return ITEM_TYPE_SALE
        } else {
            return ITEM_TYPE_DEFAULT
        }
    }

    override fun getLayoutForViewType(viewType: Int): Int {
        if (viewType == ITEM_TYPE_SALE) {
            return R.layout.inbox_item_sale
        } else {
            return R.layout.inbox_item_default
        }
    }

    override fun createViewHolderExtension(view: View, viewType: Int): ViewHolder? {
        if (viewType == ITEM_TYPE_SALE) {
            return SaleViewHolder(view)
        } else {
            return null
        }
    }

    override fun onBindViewHolder(viewHolder: IterableInboxAdapter.ViewHolder, holderExtension: ViewHolder?, message: IterableInAppMessage) {
        if (holderExtension is SaleViewHolder) {
            holderExtension.price?.text = message.customPayload?.optString("price")
        }
    }

    open class ViewHolder
    class SaleViewHolder(view: View) : ViewHolder() {
        var price: TextView? = null

        init {
            this.price = view.findViewById(R.id.price)
        }
    }
}
```

Java:

```java
 public class CustomInboxFieldsJavaFragment extends IterableInboxFragment implements IterableInboxAdapterExtension<CustomInboxFieldsJavaFragment.ViewHolder> {
    private static final int ITEM_TYPE_DEFAULT = 1;
    private static final int ITEM_TYPE_SALE = 2;

    @Override
    public int getItemViewType(@NonNull IterableInAppMessage message) {
        JSONObject payload = message.getCustomPayload();
        if (payload != null && payload.has("price")) {
            return ITEM_TYPE_SALE;
        } else {
            return ITEM_TYPE_DEFAULT;
        }
    }

    @Override
    public int getLayoutForViewType(int viewType) {
        if (viewType == ITEM_TYPE_SALE) {
            return R.layout.inbox_item_sale;
        } else {
            return R.layout.inbox_item_default;
        }
    }

    @Nullable
    @Override
    public ViewHolder createViewHolderExtension(@NonNull View view, int viewType) {
        if (viewType == ITEM_TYPE_SALE) {
            return new SaleViewHolder(view);
        } else {
            return null;
        }
    }

    @Override
    public void onBindViewHolder(@NonNull IterableInboxAdapter.ViewHolder viewHolder, @Nullable ViewHolder holderExtension, @NonNull IterableInAppMessage message) {
        if (holderExtension instanceof SaleViewHolder) {
            SaleViewHolder saleViewHolder = (SaleViewHolder) holderExtension;
            JSONObject payload = message.getCustomPayload();
            if (payload != null) {
                saleViewHolder.price.setText(payload.optString("price"));
            }
        }
    }

    static class ViewHolder {}
    static class SaleViewHolder extends ViewHolder {
        private TextView price;

        SaleViewHolder(@NonNull View view) {
            price = view.findViewById(R.id.price);
        }
    }
}
```

### Multiple sections

Mobile Inbox on Android does not provide built-in support for multiple sections.

## Further reading

User guides:
- [In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/217517406)
- [Sending In-App Messages](https://support.iterable.com/hc/articles/360034903151)
- [Events for In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/360038939972)

Developer documentation:
- Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152)
- Iterable's [Android SDK](https://support.iterable.com/hc/articles/360035019712)
- [In-App Messages Overview](https://support.iterable.com/hc/articles/360035538391)
- [In-App Messages on iOS](https://support.iterable.com/hc/articles/360035536791)
- [In-App Messages on Android](https://support.iterable.com/hc/articles/360035537231)
- [Setting up Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039137271)
- [Setting up Mobile Inbox on Android](https://support.iterable.com/hc/articles/360038744152)
- [Customizing Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039091471)
- [Animating In-App Messages with CSS](https://support.iterable.com/hc/articles/360035539271)
- [Image Carousels in In-App Messages](https://support.iterable.com/hc/articles/360035171132)
- [Testing and Troubleshooting In-App Messages](https://support.iterable.com/hc/articles/360035623391)
- [In-App Messages Without the SDK](https://support.iterable.com/hc/articles/360018709631)
- [Getting Started with Iterable's API](https://support.iterable.com/hc/articles/41044692130196)
- [API Endpoints and Sample Payloads](https://support.iterable.com/hc/articles/204780579)

