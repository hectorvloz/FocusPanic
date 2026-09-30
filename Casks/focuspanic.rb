cask "focuspanic" do
  version "1.1.0"
  sha256 "e1164cbdeecf0bda299b0469c1e774dd0145370d7fa03eea16c12cfcf74a3cf5"

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
