#!/usr/bin/env perl
# config_rm.pl – Remove **all** occurrences of a token from configuration lines.
#
# Usage: config_rm.pl PARAM TOKEN FILE
#
# The script is idempotent: if TOKEN is not present, no change is made.
#
# CONSTRAINTS: see config.pm.

use strict;
use warnings;
use lib '.';
use config;

my ($param, $token);
BEGIN {
    ($param, $token) = splice @ARGV, 0, 2;
}

while (<>) {
    if (/^\s*\Q$param\E\b/) {
        my $orig = $_;
        my $parsed = parse_line($_, $param);

        if ($parsed) {
            my @tokens = split(/\s+/, $parsed->{inner});
            my @new_tokens = grep { $_ ne $token } @tokens;
            if (@new_tokens != @tokens) {
                my $new_inner = join(" ", @new_tokens);
                $_ = reconstruct($parsed, $new_inner);
            } else {
                next;
            }
        } else {
            # Fallback: unquoted deletion.
            s/\b\Q$token\E\b\s*//g;
            s/^ //;
            s/ $//;
            if ($_ eq $orig) {
                next;
            }
        }

        print "# $orig";    # $orig already contains its newline
    }
} continue {
    print;                  # print the (possibly modified) line
}
