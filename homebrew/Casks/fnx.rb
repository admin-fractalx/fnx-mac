cask "fnx" do
  version "1.0"
  sha256 "REPLACE_AFTER_RUNNING_RELEASE_SH" # shasum -a 256 FnX-1.0.zip

  url "https://github.com/YOUR_USER/YOUR_REPO/releases/download/v#{version}/FnX-#{version}.zip"
  name "FnX"
  desc "Voice-to-text input for macOS"
  homepage "https://github.com/YOUR_USER/YOUR_REPO"

  app "FnX.app"
end
