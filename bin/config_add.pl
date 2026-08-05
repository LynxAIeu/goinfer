#!/usr/bin/env perl
# config_add.pl – Add or update a key=value pair, or ensure a flag token.
#
# Usage: config_add.pl PARAM TOKEN FILE SUFFIX
#
# If TOKEN contains '=', it is treated as a pair; otherwise as a flag.
# The script is idempotent: it only changes lines that need updating and
#                           only creates a backup when a change is made.
#
# CONSTRAINTS: see config.pm.

use strict;
use warnings;
use lib '.';
use config;

my ($param, $token, $file, $suffix);
BEGIN { ($param, $token, $file, $suffix) = splice @ARGV, 0, 4; }

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

open my $fh, '<', $file or die "$file: $!\n";
my @lines = <$fh>;
close $fh;

my $changed = 0;
my @output;

for my $line (@lines) {
    if ($line =~ /^\s*\Q$param\E\b/) {
        my $orig = $line;
        my $parsed = parse_line($line, $param);

        if ($parsed) {
            my @tokens = split(/\s+/, $parsed->{inner});
            modify_tokens($mode, \@tokens, $key, $value);
            my $new_inner = join(" ", @tokens);
            $line = reconstruct($parsed, $new_inner);
        } else {
            if ($mode eq 'pair') {
                if (!($line =~ s/(.*)\Q$key\E=[^[:space:]]*/$1$key=$value/)) {
                    $line .= ($line =~ /\S$/ ? " " : "") . "$key=$value";
                }
            } else {
                if (!($line =~ /\b\Q$key\E\b/)) {
                    $line .= ($line =~ /\S$/ ? " " : "") . $key;
                }
            }
        }

        if ($line ne $orig) {
            $changed = 1;
            push @output, "# $orig";
        }
    }
    push @output, $line;
}

if ($changed) {
    rename $file, "$file$suffix" or die "rename $file: $!\n";
    open my $out, '>', $file or die "$file: $!\n";
    print $out @output;
    close $out;
}
