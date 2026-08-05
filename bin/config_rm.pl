#!/usr/bin/env perl
# config_rm.pl – Remove **all** occurrences of a token from configuration lines.
#
# Usage: config_rm.pl PARAM TOKEN FILE SUFFIX
#
# The script is idempotent:
# if TOKEN is not present, no change is made and no backup is created.
#
# CONSTRAINTS: see config.pm.

use strict;
use warnings;
use lib '.';
use config;

my ($param, $token, $file, $suffix);
BEGIN { ($param, $token, $file, $suffix) = splice @ARGV, 0, 4; }

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
            my @new_tokens = grep { $_ ne $token } @tokens;
            if (@new_tokens != @tokens) {
                my $new_inner = join(" ", @new_tokens);
                $line = reconstruct($parsed, $new_inner);
                $changed = 1;
                push @output, "# $orig";
            }
        } else {
            my $tmp = $line;
            $tmp =~ s/\b\Q$token\E\b\s*//g;
            $tmp =~ s/^ //;
            $tmp =~ s/ $//;
            if ($tmp ne $orig) {
                $line = $tmp;
                $changed = 1;
                push @output, "# $orig";
            }
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
