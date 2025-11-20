# Terresrial Forst Monitor CLIENT

## Pre-requisites

Get and install [Flutter](https://flutter.dev/docs/get-started/install).

## Getting Started

Clone the repository and navigate to the project directory.

```bash
cd TFM-client-app
cp .env.example .env
flutter pub get
flutter run
```

## Release

Create a new release by running the following command in the project directory:

```bash
gh release create v[BUILD NUMBER] # e.g. 1.0.0+15 from pubspec.yaml
```

Read the [GitHub CLI documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) for more information on how to create, update and delete a release.
