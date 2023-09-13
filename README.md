# code_scan_listener

## Problems with barcode scanning

If you need to get barcode scanned from some hardware barcode scanner you generally have few ways to do it.

1. implement some text input control (IE. TextEdit), call focus on it and make the scan
2. listen for some special system event (IE. intent fired from Android service)
3. listen for raw keyboard events

First aproach is simple, and if you're ok to catch scanned barcodes only when you have focus on text control you're good to go and you don't need this package.

If you however need to somehow get scanned barcodes even when you don't have focus on text input control (or no text input control at all) you're left with two other options.

Listening for special system events (IE. Anroid service intents) is always tied for specific manufacturer/device that usually comes with some kind of SDK you need to implement. This means you're implementation will support listening barcode scannes only for this devices you implemented. Plus, it's not really cross platform friendly

And there's third way, simply listen for raw keyboard events and figure out what's barcode and what's not. Downside of this solution is that you need to figure out what's actual user interaction and what's barcode scan. Upside is it doesn't require any per manufacturer/device implementation and you're pretty much suporting all barcode scanners, including external ones with bluetooth or wifi. And it's cross platform friendly.

## Implementation idea


