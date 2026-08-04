#!/usr/bin/env perl
# config_rm.pl – Remove a token from configuration lines.
#
# Usage: perl -iSUFFIX -s config_rm.pl -- -param=PARAM -token=TOKEN FILE
#
# The script is idempotent: if TOKEN is not present, no change is made.
#
# CONSTRAINTS:
#   - The configuration file must use one of the formats documented in config.pm.
#   - $param and $token are expected to be alphanumeric (protected by \Q...\E).
#   - Tokens are whitespace‑separated.
#   - Only lines starting with $param (after optional whitespace) are edited.
#   - Commented lines are ignored.
#
# See config.pm for full details.

use strict;
use warnings;
use lib '.';
use config;

# $param and $token are set by perl -s

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
while (<>) {
    if (/^\s*\Q$param\E\b/) {
        my $orig = $_;
        my $parsed = parse_line($_, $param);

        if ($parsed) {
            my @tokens = split(/\s+/, $parsed->{inner});
            my @new_tokens;
            my $removed = 0;
            for my $tok (@tokens) {
                if ($tok eq $token && !$removed) {
                    $removed = 1;      # remove only the first occurrence
                    next;
                }
                push @new_tokens, $tok;
            }
            if ($removed) {
                my $new_inner = join(" ", @new_tokens);
                $_ = reconstruct($parsed, $new_inner);
            } else {
                next;                 # token not found, no change
            }
        } else {
            # Fallback: unquoted deletion.
            s/\b\Q$token\E\b\s*//;
            s/^ //;
            s/ $//;
            if ($_ eq $orig) {
                next;                 # no change
            }
        }

        print "# $orig";              # backup comment
    }
    continue {
        print;                        # print the (possibly modified) line
    }
}
