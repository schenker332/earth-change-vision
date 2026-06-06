# Earth in Motion: Visualizing Change from Space

## Requirements

This MATLAB application requires the following MathWorks toolboxes:

* **Deep Learning Toolbox**
* **Computer Vision Toolbox**
* **Signal Processing Toolbox**

> **Performance note:** After clicking a button, the interface may take a moment to update, especially on slower machines. Please wait briefly while the application performs the required image processing in the background.

## 1. Location Selection

<p align="center">
  <img src="readmePics/Locations.png" alt="Location selection" width="900" />
</p>

When the app starts, the **location selection** window opens automatically.
It contains predefined satellite image locations and also allows users to import their own image sequences via **"Add location"**.
Newly added images are automatically aligned and added to the location list in the left panel.

## 2. Main View

<p align="center">
  <img src="readmePics/UI.png" alt="Main view" width="900" />
</p>

### Left Panel: Locations

* List of all aligned locations with preview images.
* **Add location**: Imports a new image sequence.
* **Delete alignment**: Removes alignment data and metadata.
* Clicking an entry switches directly to the selected location.

### Right Panel: Image Selection

* **Aligned images**: Images that were successfully aligned.
* **Unused images**: Images that could not be aligned.
* Checkboxes can be used to include or exclude individual images.
* Scrollable image selection for any number of images. For Highlights and Segmentation, a maximum of two images can be selected.

### ROI and Crop

* **ROI selection**: Select a region of interest to realign only that part of the image sequence.
* **Crop**: Shows only the common overlapping area of all selected images and then restores the original view.

## 3. Timelapse

<p align="center">
  <img src="readmePics/Zeitraffer.png" alt="Timelapse" width="900" />
</p>

* Default view after loading a location.
* The **Play/Pause** button starts or stops automatic playback at approximately 15 fps.
* **First slider** at the top: Manually selects the current image in the sequence.
* **Second slider** at the bottom, available only in pause mode: Controls transparency between two consecutive images.
* The **date display** shows the current index and image date.

## 4. Change Highlights

<p align="center">
  <img src="readmePics/Intensität.png" alt="Change highlights: intensity view" width="900" />
</p>
<p align="center">
  <img src="readmePics/Umrandung.png" alt="Change highlights: contour view" width="900" />
</p>

This view visualizes differences between exactly two images:

* **Intensity mode**: Displays pixel changes using a colored overlay.
* **Contour mode**: Marks transition areas with contours.

Controls:

1. **Difference strength** (Slider 1): Threshold for color or contour detection.
2. **Area** (Slider 2): Minimum connected area relative to the image size.
3. **Opacity** (Slider 3, contour mode only): Transparency of the overlay.

## 5. Progress View

<p align="center">
  <img src="readmePics/Fortschritt.png" alt="Progress view" width="900" />
</p>

* Sequentially displays all detected changes as contour overlays in one axis.
* **Reverse** button: Switches the comparison direction from old-to-new to new-to-old and adjusts the base and overlay images.
* Controls and legend follow the same logic as the Highlights view.
* Displays image date pairs, for example `2020-01-01 -> 2021-01-01`.

## 6. Segmentation

<p align="center">
  <img src="readmePics/Segmentation.png" alt="Segmentation view" width="900" />
</p>

* A U-Net model segments urban landscapes into 5 classes:

  * Water, vegetation, buildings, built-up area, open land
* Displays two segmented overlays side by side.
* Shows the percentage share of each class for both points in time.
* Displays the percentage difference between both images.
* Dynamic legend with class colors in the top-left corner.

---

More information about usage and implementation details can be found in the documentation of the individual views and functions.
