#!/usr/bin/perl
#
# claude-terminal-title.pl
#
# Claude Code hook that names the macOS Terminal window/tab after the
# project folder and the task currently in flight, e.g.
#
#     ● myrepo — fix the auth redirect loop
#     ✓ myrepo — fix the auth redirect loop
#     🔔 myrepo — fix the auth redirect loop
#
# Reads the hook payload as JSON on stdin. Writes the OSC title sequence
# straight to the controlling terminal AND returns it as `terminalSequence`
# in the hook's structured output, so it works on old and new Claude Code.
#
# Pure core Perl (JSON::PP ships with macOS) — no jq, python or node needed.
#
# State is keyed by the controlling tty, so every Terminal tab keeps its own
# title, and `claude-name-tab` can pin a custom one.

use strict;
use warnings;
use JSON::PP;
use File::Basename qw(basename);
use File::Path qw(make_path);

my $MAX_TASK = 46;    # characters of task text before truncation

# ---------------------------------------------------------------- input ---

my $raw = do { local $/; <STDIN> };
$raw = '' unless defined $raw;

my $d = eval { JSON::PP->new->utf8->relaxed->decode($raw) };
$d = {} unless ref $d eq 'HASH';

my $evt    = $d->{hook_event_name} || '';
my $reason = $d->{reason}          || '';

my $cwd = $d->{cwd};
$cwd = $d->{workspace}{current_dir}
  if (!$cwd && ref $d->{workspace} eq 'HASH');
$cwd = $ENV{PWD} || '.' unless $cwd;

# field name for the prompt text has changed across versions
my $prompt = $d->{user_input};
$prompt = $d->{prompt}      unless defined $prompt && length $prompt;
$prompt = $d->{session_name} unless defined $prompt && length $prompt;
$prompt = '' unless defined $prompt;

# ---------------------------------------------------------------- state ---

# One state file per terminal tab. `ps -o tty=` on our own pid gives the
# controlling terminal we inherited from claude (e.g. "s004").
my $tty = `ps -o tty= -p $$ 2>/dev/null`;
$tty = '' unless defined $tty;
$tty =~ s/\s+//g;
$tty =~ s{/}{_}g;
$tty = 'default' if $tty eq '' || $tty eq '??';

my $dir = ($ENV{TMPDIR} || '/tmp') . '/claude-terminal-title';
eval { make_path($dir) unless -d $dir; 1 } or $dir = '/tmp';

my $override_file = "$dir/$tty.override";    # set by the "name this tab" skill
my $task_file     = "$dir/$tty.task";        # last auto-derived task

sub slurp {
    my ($f) = @_;
    open my $fh, '<:encoding(UTF-8)', $f or return '';
    local $/;
    my $s = <$fh>;
    close $fh;
    $s = '' unless defined $s;
    $s =~ s/\s+\z//;
    return $s;
}

sub spit {
    my ($f, $s) = @_;
    open my $fh, '>:encoding(UTF-8)', $f or return;
    print $fh $s;
    close $fh;
}

# ----------------------------------------------------------- task text ----

sub tidy {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\s+/ /g;
    $s =~ s/^\s+|\s+$//g;
    $s =~ s{^/\S+\s*}{};                                   # drop /slash-command
    $s =~ s/^(?:please|pls|hey|ok|okay|now|so)[,\s]+//i;    # drop filler openers
    $s =~ s/^(?:can|could|would)\s+you\s+(?:please\s+)?//i;
    $s =~ s/^\s+//;
    return $s;
}

sub truncate_words {
    my ($s) = @_;
    return $s if length($s) <= $MAX_TASK;
    my $cut = substr($s, 0, $MAX_TASK);
    $cut =~ s/\s+\S*$// if $cut =~ /\s/;                   # don't split a word
    $cut =~ s/[\s\p{P}]+$//;
    return $cut . "\x{2026}";                              # …
}

# ------------------------------------------------------------- compose ----

if ($evt eq 'SessionStart' && ($reason eq 'clear' || $reason eq 'startup')) {
    unlink $task_file, $override_file;
}

my $task;
if ($evt eq 'UserPromptSubmit') {
    $task = truncate_words(tidy($prompt));
    spit($task_file, $task) if length $task;
}
$task = slurp($task_file) unless defined $task && length $task;

my $override = slurp($override_file);
my $name     = length($override) ? $override : $task;

my $folder = basename($cwd);
$folder = 'claude' if !length($folder) || $folder eq '/';

my %GLYPH = (
    SessionStart     => '',
    UserPromptSubmit => "\x{25CF} ",    # ● working
    PostToolUse      => "\x{25CF} ",
    Notification     => "\x{1F514} ",   # 🔔 waiting on you
    Stop             => "\x{2713} ",    # ✓ done
    SubagentStop     => "\x{2713} ",
    SessionEnd       => '',
);
my $glyph = exists $GLYPH{$evt} ? $GLYPH{$evt} : '';

if ($evt eq 'SessionEnd') {
    unlink $task_file, $override_file;
    $name = '';
}

my $title = length($name) ? "$glyph$folder \x{2014} $name" : "$glyph$folder";

# -------------------------------------------------------------- output ----

my $seq = "\e]0;$title\a";

# Direct write: works on every Claude Code version.
if (open my $tty_fh, '>', '/dev/tty') {
    binmode $tty_fh, ':encoding(UTF-8)';
    print {$tty_fh} $seq;
    close $tty_fh;
}

# Structured output: the supported path on versions that understand it.
# Must be valid JSON — bare text on stdout from UserPromptSubmit would be
# injected into the prompt as extra context.
print JSON::PP->new->ascii->canonical->encode({
    hookSpecificOutput => {
        hookEventName    => ($evt || 'SessionStart'),
        terminalSequence => $seq,
    },
});

exit 0;
