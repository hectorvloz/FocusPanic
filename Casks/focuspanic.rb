cask "focuspanic" do
  version "1.1.0"
  sha256 "4c34622b2c7dbf7506774049c6e73b6b1b58a2fb7cb9d1ee928ecd630490ecda"

  url "https://github.com/hectorvloz/FocusPanic/releases/download/v#{version}/FocusPanic.dmg"
  name "FocusPanic"
  desc "Radical focus & anti-procrastination blocking system designed for ADHD"
  homepage "https://github.com/hectorvloz/FocusPanic"

  depends_on macos: ">= :ventura"

  app "FocusPanic.app"

  zap trash: [
    "~/Library/Preferences/com.focuspanic.mac.plist",
    "~/Library/Application Support/FocusPanic",
  ]
end
