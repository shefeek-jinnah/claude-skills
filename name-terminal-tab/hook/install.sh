#!/bin/bash
#
# Installer for the Claude Code terminal-title hook (macOS).
#
#   ./install.sh              install / update
#   ./install.sh --uninstall  remove the hooks and the scripts
#
# Installs:
#   ~/.claude/hooks/claude-terminal-title.pl       the hook itself
#   ~/.local/bin/claude-name-tab                   manual rename helper
#   ~/.claude/skills/name-terminal-tab/SKILL.md    the "name this tab" skill
# and merges the hook wiring into ~/.claude/settings.json, keeping a backup
# and leaving any hooks you already have untouched.
#
# Run it from anywhere: every path is resolved relative to this script, which
# lives in the skill's hook/ subfolder with SKILL.md one level up.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOK_DIR="$CLAUDE_DIR/hooks"
HOOK_PATH="$HOOK_DIR/claude-terminal-title.pl"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/claude-name-tab"
SETTINGS="$CLAUDE_DIR/settings.json"
SKILL_SRC="$SRC_DIR/../SKILL.md"
SKILL_DIR="$CLAUDE_DIR/skills/name-terminal-tab"
SKILL_PATH="$SKILL_DIR/SKILL.md"

UNINSTALL=0
[ "${1:-}" = "--uninstall" ] && UNINSTALL=1

if [ ! -x /usr/bin/perl ] && ! command -v perl >/dev/null 2>&1; then
  echo "error: perl not found (it ships with macOS — is this macOS?)" >&2
  exit 1
fi

mkdir -p "$HOOK_DIR" "$BIN_DIR"

if [ "$UNINSTALL" -eq 0 ]; then
  install -m 0755 "$SRC_DIR/claude-terminal-title.pl" "$HOOK_PATH"
  install -m 0755 "$SRC_DIR/claude-name-tab" "$BIN_PATH"
  if [ -f "$SKILL_SRC" ]; then
    mkdir -p "$SKILL_DIR"
    install -m 0644 "$SKILL_SRC" "$SKILL_PATH"
  else
    echo "note: no SKILL.md at $SKILL_SRC — installing the hook only." >&2
  fi
fi

# ---- merge (or strip) the hook entries in settings.json -------------------

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"

HOOK_PATH="$HOOK_PATH" UNINSTALL="$UNINSTALL" perl -MJSON::PP -e '
  my $path      = $ENV{HOOK_PATH};
  my $uninstall = $ENV{UNINSTALL};
  my $file      = shift @ARGV;

  open my $in, "<:encoding(UTF-8)", $file or die "cannot read $file: $!\n";
  my $raw = do { local $/; <$in> };
  close $in;
  $raw = "{}" unless defined $raw && $raw =~ /\S/;

  my $cfg = eval { JSON::PP->new->relaxed->decode($raw) };
  die "settings.json is not valid JSON — fix it and re-run\n" unless ref $cfg eq "HASH";

  $cfg->{hooks} = {} unless ref $cfg->{hooks} eq "HASH";

  my @events = qw(SessionStart UserPromptSubmit Stop SubagentStop Notification SessionEnd);

  for my $evt (@events) {
      my $groups = $cfg->{hooks}{$evt};
      $groups = [] unless ref $groups eq "ARRAY";

      # drop any previous copy of our hook, so re-running is idempotent
      for my $g (@$groups) {
          next unless ref $g eq "HASH" && ref $g->{hooks} eq "ARRAY";
          @{ $g->{hooks} } =
            grep { !(ref $_ eq "HASH" && ($_->{command} // "") =~ /claude-terminal-title\.pl/) }
            @{ $g->{hooks} };
      }
      # prune groups that are now empty
      @$groups = grep {
          !( ref $_ eq "HASH" && ref $_->{hooks} eq "ARRAY" && @{ $_->{hooks} } == 0 )
      } @$groups;

      unless ($uninstall) {
          push @$groups, {
              matcher => "",
              hooks   => [ { type => "command", command => $path, timeout => 5 } ],
          };
      }

      if (@$groups) { $cfg->{hooks}{$evt} = $groups }
      else          { delete $cfg->{hooks}{$evt} }
  }

  delete $cfg->{hooks} unless %{ $cfg->{hooks} };

  open my $out, ">:encoding(UTF-8)", $file or die "cannot write $file: $!\n";
  print {$out} JSON::PP->new->pretty->canonical->encode($cfg);
  close $out;
' "$SETTINGS"

if [ "$UNINSTALL" -eq 1 ]; then
  rm -f "$HOOK_PATH" "$BIN_PATH" "$SKILL_PATH"
  rmdir "$SKILL_DIR" 2>/dev/null || true
  echo "Removed the terminal-title hook. Backup of your previous settings.json is alongside it."
  exit 0
fi

echo "Installed:"
echo "  hook    $HOOK_PATH"
echo "  helper  $BIN_PATH"
if [ -f "$SKILL_PATH" ]; then
  echo "  skill   $SKILL_PATH"
fi
echo "  wired into $SETTINGS (previous version backed up)"
echo
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not on your PATH — add it if you want to run claude-name-tab by hand." ;;
esac
echo "Start a new Claude Code session to see it take effect."
