# Self-hosted GitHub Actions runner for bgdude on Unraid.
# Flutter + Android toolchain baked in so branch builds are fast (no per-run SDK downloads).
# Versions pinned to match .github/workflows/ci.yml — keep them in sync.
#
# NOTE: this is a starting template, not battle-tested — the bits most likely to need a tweak
# are marked "ADJUST". Build phase 1 (analyze/test/build-apk) first; turn on WITH_EMULATOR only
# once phase 1 is green and you've passed /dev/kvm through (see README, "Phase 2").
FROM myoung34/github-runner:latest

# --- versions (match ci.yml + android/app/build.gradle) ---
ARG FLUTTER_VERSION=3.44.4
ARG ANDROID_CMDLINE_TOOLS=11076708
ARG ANDROID_PLATFORMS="platforms;android-36 platforms;android-37"
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG WITH_EMULATOR=false
ARG EMULATOR_API=34

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${PATH}"

# JDK 17 + build deps (libglu1-mesa is needed by the Flutter/Android tooling)
RUN apt-get update && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless git curl unzip xz-utils zip ca-certificates libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Android SDK: cmdline-tools + platforms + build-tools (+ emulator/system-image if WITH_EMULATOR)
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" -o /tmp/cmdtools.zip \
    && unzip -q /tmp/cmdtools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm /tmp/cmdtools.zip \
    && yes | sdkmanager --licenses >/dev/null \
    && sdkmanager --install "platform-tools" ${ANDROID_PLATFORMS} "build-tools;${ANDROID_BUILD_TOOLS}" >/dev/null \
    && if [ "${WITH_EMULATOR}" = "true" ]; then \
         sdkmanager --install "emulator" "system-images;android-${EMULATOR_API};google_apis;x86_64" >/dev/null \
         && echo "no" | avdmanager create avd -n "bgdude_api${EMULATOR_API}" \
              -k "system-images;android-${EMULATOR_API};google_apis;x86_64" --device pixel_6 --force ; \
       fi

# Flutter SDK (pinned) + Android artifacts precache
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz \
    && tar xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory "${FLUTTER_HOME}" \
    && flutter --version \
    && flutter precache --android

# The runner user (myoung34 image) needs read/exec on the baked SDKs. World-rx keeps it simple
# for a dedicated CI box; tighten to a chown if you prefer. ADJUST if your image's runner uid differs.
RUN chmod -R a+rX "${FLUTTER_HOME}" "${ANDROID_SDK_ROOT}"

# myoung34/github-runner's own entrypoint handles registration + the run loop — do not override it.
