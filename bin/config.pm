package config;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(parse_line reconstruct);

# ==============================================================================
# CONFIGURATION EDITING CONSTRAINTS
#
# The editing functions assume that the configuration file uses one of these
# formats for a parameter assignment:
#
#   PARAM="value token ..."         (double‑quoted string)
#   PARAM='value token ...'         (single‑quoted string)
#   PARAM=(value token ...)         (array / parentheses)
#   PARAM[n]="value token ..."      (indexed array, double‑quoted)
#   PARAM[n]='value token ...'      (indexed array, single‑quoted)
#   PARAM[...]+="value token ..."   (append to indexed array, double‑quoted)
#   PARAM[...]+='value token ...'   (append to indexed array, single‑quoted)
#
# Tokens are separated by whitespace. The scripts preserve the original quoting
# style and whitespace normalisation (multiple spaces are collapsed to one).
#
# The parameter name ($param) and token ($token) should be alphanumeric
# (letters, digits, underscore). The scripts use \Q...\E to protect against
# regex metacharacters, but they are not expected to contain '=' (for flags) or
# any special characters that would interfere with parsing.
#
# Lines that are already commented (starting with '#') are ignored.
# Lines that do not start with the parameter (after optional whitespace) are
# passed through unchanged.
#
# The scripts are idempotent: they will not change a line if the desired state
# is already present. A backup file is created on every invocation (via perl -i).
# ==============================================================================

# -----------------------------------------------------------------------------
# parse_line – Extract prefix, inner content, suffix, and delimiter type.
# The trailing newline is preserved in the suffix so that reconstruct
# emits a properly terminated line.
# -----------------------------------------------------------------------------
sub parse_line {
    my ($line, $param) = @_;

    if ($line =~ /^(\s*\Q$param\E\s*=\s*)\(([^)]*)\)(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => '()' };
    }
    elsif ($line =~ /^(\s*\Q$param\E\s*\[\w+\]\s*\+=\s*)"([^"]*)"(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => 'dq' };
    }
    elsif ($line =~ /^(\s*\Q$param\E\s*\[\w+\]\s*\+=\s*)'([^']*)'(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => 'sq' };
    }
    elsif ($line =~ /^(\s*\Q$param\E\s*\[\d+\]\s*=\s*)"([^"]*)"(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => 'dq' };
    }
    elsif ($line =~ /^(\s*\Q$param\E\s*\[\d+\]\s*=\s*)'([^']*)'(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => 'sq' };
    }
    elsif ($line =~ /^(\s*\Q$param\E\s*=\s*)"([^"]*)"(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => 'dq' };
    }
    elsif ($line =~ /^(\s*\Q$param\E\s*=\s*)'([^']*)'(.*\n?)$/) {
        return { prefix => $1, inner => $2, suffix => $3, delim => 'sq' };
    }
    return undef;   # unquoted / fallback
}

# -----------------------------------------------------------------------------
# reconstruct – Rebuild the line from parsed structure and new inner content.
# -----------------------------------------------------------------------------
sub reconstruct {
    my ($parsed, $new_inner) = @_;
    my $delim = $parsed->{delim};
    if ($delim eq '()') {
        return $parsed->{prefix} . '(' . $new_inner . ')' . $parsed->{suffix};
    } elsif ($delim eq 'dq') {
        return $parsed->{prefix} . '"' . $new_inner . '"' . $parsed->{suffix};
    } elsif ($delim eq 'sq') {
        return $parsed->{prefix} . "'" . $new_inner . "'" . $parsed->{suffix};
    }
    # fallback (should not happen)
    return $parsed->{prefix} . $new_inner . $parsed->{suffix};
}

1;
