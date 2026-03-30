#!/bin/bash

set -e

BRANCH="gh-pages"
DEMO_DIR="demo"
BUILD_DIR="$DEMO_DIR/build/web"

echo "🚀 Building Flutter Web Demo..."

git checkout main
git pull origin main

cd $DEMO_DIR
flutter pub get
flutter build web --release
cd ..

echo "Build Completed!"

git checkout $BRANCH

echo "Preventing build folder from being deleted..."
mv $BUILD_DIR /tmp/build_web

echo "Cleaning old deployment files..."
rm -rf ../trina_grid/*
rm -rf .dart_tool

echo "🔁 Moving demo build files to the repository root..."
mv /tmp/build_web/* .

rm -rf /tmp/build_web

git add .
git commit -m "🚀 Deploy updated Flutter Web Demo"
git push origin $BRANCH

git checkout main

flutter pub get
cd demo
flutter pub get
cd ..

echo "🎉 Deployment Completed!"
