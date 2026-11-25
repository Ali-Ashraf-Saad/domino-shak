FROM ruby:3.3-slim

ENV FASTLANE_SKIP_UPDATE_CHECK=1 \
    FASTLANE_DISABLE_ANONYMOUS_REPORTING=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential git ca-certificates zlib1g-dev libffi-dev \
 && rm -rf /var/lib/apt/lists/* \
 && gem install fastlane --no-document

WORKDIR /workspace
