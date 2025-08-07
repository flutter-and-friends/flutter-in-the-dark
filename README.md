# Flutter in the Dark

This repository is a monorepo containing the Flutter applications for the "Flutter in the Dark" event series. The projects are managed using the [Melos](https://melos.invertase.dev) tool.

## Getting Started

To get started with this project, you will need to have Flutter and Melos installed.

1.  **Install Flutter:** Follow the instructions on the [official Flutter website](https://flutter.dev/docs/get-started/install).
2.  **Activate Melos:**
    ```bash
    dart pub global activate melos
    ```
3.  **Bootstrap the project:** This will install all the dependencies for the packages in this monorepo.
    ```bash
    melos bootstrap
    ```

## Packages in this Monorepo

This repository contains the following applications:

*   `apps/fitd23`: The Flutter in the Dark app for the 2023 event.
*   `apps/fitd24`: The Flutter in the Dark app for the 2024 event.
*   `apps/fitd25`: The Flutter in the Dark app for the 2025 event.

## Scripts

You can use the following Melos scripts to manage the projects:

*   `melos run build_web`: Build the web version of all applications.
*   `melos run fix`: Apply Dart fixes to all packages.
*   `melos run upgrade`: Upgrade dependencies for all packages.
