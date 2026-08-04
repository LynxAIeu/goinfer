#!/usr/bin/env perl
# config_add.pl – Add or update a key=value pair, or ensure a flag token.
#
# Usage: perl -iSUFFIX -s config_add.pl -- -param=PARAM -token=TOKEN FILE
#
# If TOKEN contains '=', it is treated as a pair; otherwise as a flag.
# The script is idempotent: it only changes lines that need updating.
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
my $mode = ($token =~ /=/) ? 'pair' : 'flag';
my ($key, $value) = $mode eq 'pair' ? split /=/, $token, 2 : ($token, undef);

# -----------------------------------------------------------------------------
# modify_tokens – In‑place modification of token array for the given mode.
# -----------------------------------------------------------------------------
sub modify_tokens {
    my ($mode, $tokens_ref, $key, $value) = @_;
    if ($mode eq 'pair') {
        my $found = 0;
        for my $tok (@$tokens_ref) {
            if ($tok =~ /^\Q$key\E=/) {
                $tok = "$key=$value";
                $found = 1;
                last;
            }
        }
        push @$tokens_ref, "$key=$value" unless $found;
    } else {
        my $found = 0;
        for my $tok (@$tokens_ref) {
            if ($tok eq $key) {
                $found = 1;
                last;
            }
        }
        push @$tokens_ref, $key unless $found;
    }
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
while (<>) {
    # Only consider lines that start with the parameter (as a whole word).
    if (/^\s*\Q$param\E\b/) {
        my $orig = $_;
        my $parsed = parse_line($_, $param);

        if ($parsed) {
            my @tokens = split(/\s+/, $parsed->{inner});
            modify_tokens($mode, \@tokens, $key, $value);
            my $new_inner = join(" ", @tokens);
            $_ = reconstruct($parsed, $new_inner);
        } else {
            # Fallback: unquoted editing (naive).
            if ($mode eq 'pair') {
                # Try to update existing key; else append.
                if (!s/(.*)\Q$key\E=[^[:space:]]*/$1$key=$value/) {
                    $_ .= (/\S$/ ? " " : "") . "$key=$value";
                }
            } else {
                # Add flag if missing.
                if (!/\b\Q$key\E\b/) {
                    $_ .= (/\S$/ ? " " : "") . $key;
                }
            }
        }

        # If no change, skip backup comment and printing the modified line.
        if ($_ eq $orig) {
            next;
        }
        print "# $orig";   # backup comment
    }
    continue {
        print;             # print the (possibly modified) line
    }
}
