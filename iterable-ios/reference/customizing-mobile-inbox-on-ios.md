---
slug: customizing-mobile-inbox-on-ios
feature: mobile-inbox
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Customizing Mobile Inbox on iOS
source_url: https://support.iterable.com/hc/articles/360039091471
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/customizing-mobile-inbox-on-ios/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: a28a735c2c1a78e215f27dbe3fad6926cdf12187
fetched_at: 2026-10-02T13:52:10.824Z
summary: A [mobile inbox](https://support.iterable.com/hc/articles/217517406)
  provides an app-specific place for users to save in-app messages to read
  later.
---
# Customizing Mobile Inbox on iOS

A [mobile inbox](https://support.iterable.com/hc/articles/217517406) provides an
app-specific place for users to save in-app messages to read later. 

Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152)
includes a default user interface for a mobile inbox, and you can customize it
to match your organization's branding and styles, and to display any necessary
fields. 

This document describes different ways to customize the mobile inbox provided by
Iterable's Android SDK.

## Setting up the mobile inbox

Before customizing your app's mobile inbox, read [Setting up Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039137271)
to learn how to set it up and display it.

## Sample app

To better understand how to customize your app's mobile inbox, take a look 
the code for the **Inbox Customization** [sample project](https://github.com/Iterable/iterable-swift-sdk/tree/master/sample-apps/inbox-customization) 
(found in the same GitHub respository as Iterable's iOS SDK). 

The sample app relies on mock data and doesn't require any configuration 
changes in order to run. Modify its data and views to experiment with the
various customization options described below.

## Customizing the mobile inbox

This section describes how to customize the user interface of the mobile inbox
embedded in your iOS mobile app.

> [!NOTE]
> To customize the inbox, it's best to prefer delegation and custom table cells
> over inheriting from the mobile inbox view controller classes.

### Empty state

In an empty mobile inbox, you can display custom text (title and body) to help
orient your users. These values are blank by default. For example:

To set this text, set the `noMessagesTitle` and `noMessagesBody` properties on 
an instance of `IterableInboxNavigationViewController` or 
`IterableInboxViewController`. For example:

_Swift_

```swift
iterableInboxViewController.noMessagesTitle = "No saved messages"
iterableInboxViewController.noMessagesBody = "Check again later!"
```

_Objective-C_

```objectivec
iterableInboxViewController.noMessagesTitle = @"No saved messages"
iterableInboxViewController.noMessagesBody = @"Check again later!"
```

### Message display style (popup or navigation)

To change the way that the mobile inbox displays messages, set the `isPopup`
property on its view controller:

- `true` (default) - display messages as popups in the inbox
- `false` - display messages on the navigation stack

### Navigation title

To change the title of the inbox, set the `navTitle` property on
`IterableInboxNavigationViewController`. Choose a simple title such as `Inbox`.

### Cell layout, colors and font

> [!TIP]
> In the [sample app](#sample-app), tap **Inbox with Custom Cell** to see an
> example of an inbox that uses custom cells.

To modify the font, color or layout of inbox table view cells:

1. Copy [`swift-sdk/Resources/SampleInboxCell.xib`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/Resources/SampleInboxCell.xib) 
   from the **swift-sdk** repository to your project.

2. Rename the file. For example, you might call it `CustomInboxCell.xib`.

3. In the new file, change the layout, colors and font however you'd like.

4. Tell the mobile inbox view controller to use the custom nib file:

    - If you're using a storyboard, select the `IterableInboxNavigationViewController`,
      open its **Attributes** inspector, and set the **Cell Nib Name** property
      to your custom cell name. For example:

    - Otherwise, set the `cellNibName` property on the mobile inbox view
      controller to the name of your custom cell. For example:

        ```swift
        let viewController = IterableInboxNavigationViewController()
        viewController.cellNibName = "CustomInboxCell"
        present(viewController, animated: true)
        ```

### Date format and visibility

> [!TIP]
> In the [sample app](#sample-app), tap **Change Date Format** to see an
> example of an inbox that changes the date format of the table view cells.

To change the format or visibility of the date field for each message cell,
set the `dateMapper` property on the mobile inbox [delegate](#creating-a-custom-delegate-for-the-mobile-inbox).
This property is a closure that takes an `IterableInAppMessage` and returns
an optional `String`:
    
- To hide the date, it should return `nil`.
- Otherwise, it should return the formatted date.

This example uses a `dateMapper` provided by Iterable's iOS SDK:

```swift
public class MyCustomInboxViewDelegate1: IterableInboxViewControllerViewDelegate {
    public required init() {}
    public let dateMapper = IterableInboxViewController.DefaultDateMapper.localizedShortDateShortTime
}
```

This example uses a custom `dateMapper`:

```swift
public class MyCustomInboxViewDelegate2: IterableInboxViewControllerViewDelegate {
    public required init() {}
    // shows short date and short time
    public var dateMapper: (IterableInAppMessage) -> String? = { message in
        guard let date = message.createdAt else {
            return nil
        }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}
```

### Filtering messages

> [!TIP]
> In the [sample app](#sample-app), tap **Filter by Message Type** or
> **Filter by Message Title** to see an example of an inbox that uses custom
> filtering.

To filter which messages are displayed in the mobile inbox, set the 
`filter` property on the mobile inbox  [delegate](#creating-a-custom-delegate-for-the-mobile-inbox).
This property is a closure that takes an `IterableInAppMessage` and returns a
`Bool`. Return `true` if the message should be displayed and `false` if it
should not.

This example uses a `filter` provided by Iterable's iOS SDK, which filters on
the provided message types:

```swift
public class MyCustomInboxViewDelegate1: IterableInboxViewControllerViewDelegate {
    public required init() {}
    public let filter = IterableInboxViewController.DefaultFilter.usingCustomPayloadMessageType(in: "marketing", "newsFeed")
}
```

This example uses a custom `filter`:

```swift
public class MyCustomInboxViewDelegate2: IterableInboxViewControllerViewDelegate {
    public required init() {}
    // Only displays messages where "shouldDisplay" is set to true.
    public let filter: (IterableInAppMessage) -> Bool = { message in
        guard let customPayload = message.customPayload as? [String: Any] else {
            return false
        }
        return customPayload["shouldDisplay"] as? Bool ?? false
    }
}
```

### Sorting messages

> [!TIP]
> In the [sample app](#sample-app), tap **Sort by Title Ascending** or 
> **Sort by Date Ascending** to see an example of an inbox that changes the way 
> messages are sorted.

By default, Mobile Inbox sorts messages descending by date. However, it is 
possible to sort the message order in other ways.

To sort the messages in the mobile inbox, set the `comparator` property on 
the mobile inbox [delegate](#creating-a-custom-delegate-for-the-mobile-inbox).
This property is a closure that takes two `IterableInAppMessage` values and
returns a `Bool`—`true` if the first message should appear before the second
message, and `false` otherwise.

The following example uses a `comparator` provided by Iterable's iOS SDK, which
sorts messages ascending by date:

```swift
// Sort by ascending date (instead of default descending)
public class MyCustomInboxViewDelegate1: IterableInboxViewControllerViewDelegate {
    public required init() {}
    public let comparator = IterableInboxViewController.DefaultComparator.ascending
}
```
### Adding fields to the inbox cell

> [!TIP]
> In the [sample app](#sample-app), tap **Additional Fields** to see an
> example of an inbox that has additional fields on each cell.

To add additional fields to the items displayed in the mobile inbox:

1. Follow the instructions in [Cell layout, colors and font](#cell-layout-colors-and-font)
   to set up a custom table view cell.

2. In Xcode, associate a Swift class with the cell.

3. Open up the new table view cell. Add additional fields and connect them to
   outlets in the code associated with the cell.

4. In the mobile inbox [delegate](#creating-a-custom-delegate-for-the-mobile-inbox),
   implement `func renderAdditionalFields(forCell:withMessage:)`. In this method, 
   set values for the new fields. 

For example, this code sets the text on a `discountLbl` field:

```swift
public func renderAdditionalFields(forCell cell: IterableInboxCell, withMessage message: IterableInAppMessage) {
    guard
        let customCell = cell as? AdditionalFieldsInboxCell,
        let payload = message.customPayload as? [String: AnyHashable],
        let discount = payload["discount"] as? String else {
        return
    }
    customCell.discountLbl?.text = "\(discount)"
}
```

### Multiple cell layouts

> [!TIP]
> In the [sample app](#sample-app), tap **Multiple Cell Types** to see an
> example of an inbox that uses multiple cell types.

To display different inbox items with different interfaces, make two configuration
changes to the mobile inbox [delegate](#creating-a-custom-delegate-for-the-mobile-inbox):

1. Set the `customNibNames` property to an array of custom cell nib file names
   (that you've included in your project).

2. Set the `customNibNameMapper` property. This property is a closure that takes
   an `IterableInAppMessage` and returns an optional string:

    - To use the default layout, return `nil`.
    - To use a custom layout, return the name of the nib file.

For example, the following code sets the `customNibNames` array and then uses
a `customNibNameMapper` provided by Iterable's iOS SDK, which maps the in-app
message to a custom cell name based on a `customCellName` property in its 
payload:

```swift
public class MultipleCellTypesInboxViewDelegate: IterableInboxViewControllerViewDelegate {
    public required init() {}
    public let customNibNames = ["CustomInboxCell1", "CustomInboxCell2", "AdvancedInboxCell", "CustomInboxCell"]
    public let customNibNameMapper = IterableInboxViewController.DefaultNibNameMapper.usingCustomPayloadNibName
}
```

### Multiple sections

> [!TIP]
> In the [sample app](#sample-app), tap **Multiple Sections** to see an
> example of an inbox that uses custom cells.

To separate a mobile inbox into multiple sections, set the 
`messageToSectionMapper` property on the mobile inbox [delegate](#creating-a-custom-delegate-for-the-mobile-inbox). 
This property takes an `IterableInAppMessage` and returns an `Int` that 
represents the section in which it should appear.

A mobile inbox uses the section numbers returned by a `messageToSectionMapper` 
for relative section ordering—not absolute. For example, if a 
`messageToSectionMapper` returns sections -1, 1, -1, and 2 for four in-app
messages, they will appear in sections 0, 1, 0, and 2 (respectively). 

The following code uses a `messageToSectionMapper` provided by Iterable's iOS
SDK, which determines where to display an in-app message by examining the
`messageSection` property in its custom payload.

```swift
public class MultipleSectionsViewDelegate: IterableInboxViewControllerViewDelegate {
    public required init() {}
    public let messageToSectionMapper: ((IterableInAppMessage) -> Int) = IterableInboxViewController.DefaultSectionMapper.usingCustomPayloadMessageSection
}
```

## Creating a custom delegate for the mobile inbox

Use a delegate to customize your mobile inbox in various ways:

- Message filtering
- Message sorting
- Message sections
- Date display
- Custom UI for particular messages
- Additional fields to render

To create a custom delegate:

1. Create a class that implements the [`IterableInboxViewControllerViewDelegate`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/IterableInboxViewController.swift)
   protocol. For example, you might call it `AdvancedInboxViewDelegate`.

2. Provide implementations for the parts of the protocol that correspond to
   the customizations you'd like to make (it isn't necessary to implement the
   entire protocol).

3. Instantiate and set up the delegate.

    - If you set the inbox view controller in a storyboard:

        Set the view controller's **View Delegate Class Name** to:

        `<YOUR_MODULE_NAME>.<YOUR_CUSTOM_DELEGATE_CLASS_NAME>` 
        
        For example, this screenshot sets **View Delegate Class Name** to 
        `inbox_customization.AdvancedInboxViewDelegate`:

        :::warning IMPORTANT
        Don't forget to include the module in the value for 
        **View Delegate Class Name**.
        :::
    
    - If you set the inbox view controller in code:
    
        Set the view controller's `viewDelegate` property to an instance of the 
        custom delegate. For example, this code sets the delegate to an object of 
        type `AdvancedInboxViewDelegate`:

        ```swift
        iterableInboxNavController.viewDelegate = AdvancedInboxViewDelegate() 
        present(iterableInboxNavController, animated:true)
        ```
