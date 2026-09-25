cask "macskk-kakutei-undo" do
  # NOTE: before_comma is the upstream release this is built from, after_comma
  # is the revision of patches/kakutei-undo.patch on top of it. Bumping only the
  # patch does not need an upstream release.
  version "2.20.0,1"
  sha256 "f30eeb3abbd0bada40bb626b6c840aaabd66a2b797b4fbb42bdd6dfdd1795ca2"

  url "https://github.com/delphinus/homebrew-macskk/releases/download/v#{version.before_comma}-#{version.after_comma}/macSKK.app.zip"
  name "macSKK with kakutei undo"
  desc "Japanese input method (SKK) with a kakutei undo patch that is not upstream yet"
  homepage "https://github.com/mtgto/macSKK"

  depends_on macos: :ventura
  # NOTE: The official cask installs the same bundle identifier into
  # /Library/Input Methods via a pkg. Two copies make macOS launch the wrong one.
  conflicts_with cask: "macskk"

  # NOTE: input_method puts this in ~/Library/Input Methods, which needs no sudo.
  # That is the whole reason this is a cask built from our own release rather
  # than the upstream pkg.
  input_method "macSKK.app"

  uninstall quit: [
    "net.mtgto.inputmethod.macSKK",
    "net.mtgto.inputmethod.macSKK.FetchUpdateService",
    "net.mtgto.inputmethod.macSKK.SKKServClient",
  ]

  # NOTE: The user dictionary lives in the container and is shared with the
  # official build, so zap only on an explicit request.
  zap trash: [
    "~/Library/Application Scripts/net.mtgto.inputmethod.macSKK",
    "~/Library/Containers/net.mtgto.inputmethod.macSKK",
  ]

  preflight_steps do
    # NOTE: conflicts_with only sees casks brew knows about. A hand-built app
    # copied into /Library/Input Methods is invisible to brew and is exactly
    # what breaks input: TIS launches an input method by bundle identifier, so
    # with two registrations it can pick the other one and swallow every key.
    if_path_exists "/Library/Input Methods/macSKK.app" do
      warn <<~EOS
        /Library/Input Methods/macSKK.app already exists.

        macOS launches an input method by its bundle identifier, so having
        macSKK in both /Library/Input Methods and ~/Library/Input Methods makes
        it launch an unpredictable one. Remove the system-wide copy first:

            brew uninstall --cask macskk     # if it came from the official cask
            sudo rm -rf "/Library/Input Methods/macSKK.app"

        Then re-run this install and add the input source again in
        System Settings > Keyboard > Input Sources.
      EOS
      # NOTE: the steps DSL has no odie, and a failing command is the only way
      # to abort. Spell the condition out so the error names the path even
      # after the warning above has scrolled away. (`brew style` does not list
      # `warn` as a step, but the runner supports it.)
      run "/bin/test", args: ["!", "-e", "/Library/Input Methods/macSKK.app"]
    end
  end

  # NOTE: the steps DSL has no token for input_methoddir, and `~` in a step
  # expands against the sandbox's fake home, so resolve the install target
  # while this is still plain Ruby. `brew style` wants literal arguments here,
  # but a literal cannot name the home directory.
  installed_app = "#{cask.config.input_methoddir}/macSKK.app"

  postflight_steps do
    # NOTE: This app is ad-hoc signed (no Developer ID), and casks quarantine
    # what they download. Drop the flag so TIS can load it.
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", installed_app],
        writable_paths: [installed_app],
        must_succeed:   false
  end

  caveats <<~EOS
    This build is ad-hoc signed and does not auto-update itself. Upgrades come
    from this tap, so keep it up to date with `brew upgrade`.

    After the first install, add the input source in
    System Settings > Keyboard > Input Sources.

    The user dictionary, skkserv settings and containers are shared with the
    official build because the bundle identifier is the same.
  EOS
end
