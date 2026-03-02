# INSTALLATION GUIDE

Requirements: 
- **iOS 17+** 
- iPhone XS or newer
- MacOS (any is fine, just need Xcode)
- Apple ID
- Data transfer cable (from Mac to iPhone)

For all files installed, try to keep them somewhere you remember so it's easy to delete when finished (like Downloads folder)

1. Install Xcode
    - [App Store (Recommended)](https://apps.apple.com/us/app/xcode/id497799835?mt=12)
    - [Older versions (Requires Apple ID)](https://developer.apple.com/download/all/?q=xcode) - Open in Incognito tab if it keeps redirecting you back to your account
    - [Which version of Xcode to install?](https://developer.apple.com/support/xcode/)

2. Agree to all Xcode popups and install the iOS simulator (which includes iOS build support on your device)

3. Fork this repository if you would like to make changes

4. Open Xcode and select `clone git repository` and paste `https://github.com/GarfieldFluffJr/Recon` or your forked repository

5. Click `Recon` -> `Signing & Capabilities`

    - Change the `Team` field to your own Apple ID. 
    - Change the `Bundle Identifier` from `louieyin` to your own first and last name.
  
6. Plug in your iPhone into your Mac. Make sure to trust the device

7. Once your device is connected, in the top bar, select your iPhone
    - It should look like `Recon > Your device name`
  
8. In the top-left corner, click run 
    - Or `Menu Bar -> Product -> Run`

9. Follow all Xcode and iPhone instructions **carefully** to bypass security concerns and iOS requirements

10. Congratulations! You have successfully installed Recon on your iPhone! You can now safely unplug your devices and delete Xcode along with all other associated files (check your `Recents` folder or where you saved everything upon installation)

## Uninstall

Just delete the app on your iPhone as usual. You can also turn off developer mode on your iPhone if you wish to do so.