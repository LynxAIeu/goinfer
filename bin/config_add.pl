#!/usr/bin/env perl
# config_add.pl – Add or update a key=value pair, or ensure a flag token.
#
# Usage: config_add.pl PARAM TOKEN FILE
#
# If TOKEN contains '=', it is treated as a pair; otherwise as a flag.
# The script is idempotent: it only changes lines that need updating.
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

my $mode = ($token =~ /=/) ? 'pair' : 'flag';
my ($key, $value) = $mode eq 'pair' ? split /=/, $token, 2 : ($token, undef);

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

while (<>) {
    if (/^\s*\Q$param\E\b/) {
        my $orig = $_;
        my $parsed = parse_line($_, $param);

        if ($parsed) {
            my @tokens = split(/\s+/, $parsed->{inner});
            modify_tokens($mode, \@tokens, $key, $value);
            my $new_inner = join(" ", @tokens);
            $_ = reconstruct($parsed, $new_inner);
        } else {
            # Fallback: unquoted editing.
            if ($mode eq 'pair') {
                if (!s/(.*)\Q$key\E=[^[:space:]]*/$1$key=$value/) {
                    $_ .= (/\S$/ ? " " : "") . "$key=$value";
                }
            } else {
                if (!/\b\Q$key\E\b/) {
                    $_ .= (/\S$/ ? " " : "") . $key;
                }
            }
        }

        if ($_ eq $orig) {
            next;
        }
        print "# $orig";    # $orig already contains its newline
    }
} continue {
    print;                  # print the (possibly modified) line
}
