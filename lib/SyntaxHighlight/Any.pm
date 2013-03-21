package SyntaxHighlight::Any;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(highlight_string detect_language list_languages);

our %LANGS = (
    yaml => {pygments => 'yaml'},
    perl => {pygments => 'perl', sh => 'perl'},
    json => {pygments => 'json', sh => 'js'  },
    js   => {pygments => 'js'  , sh => 'js'  },
    php  => {pygments => 'php' , sh => 'php' },
);

sub _try_source_highlight_binary {
    require File::Which;
    require IPC::Run;

    my ($strref, $opts) = @_;

    my $path = File::Which::which("source-highlight");
    return undef unless $path;

    my $out;
    IPC::Run::run(
        [$path,
         "-f", ($opts->{output} eq 'ansi' ? "esc" : "html"),
         "-s", $LANGS{ $opts->{lang} }{sh}],
        $strref,
        \$out,
    );
    return undef if $?;
    return $out;
}

sub _try_pygments_binary {
    require File::Which;
    require IPC::Run;

    my ($strref, $opts) = @_;

    my $path = File::Which::which("pygmentize");
    return undef unless $path;

    my $out;
    IPC::Run::run(
        [$path,
         "-f", ($opts->{output} eq 'ansi' ? "terminal" : "html"),
         "-l", $LANGS{ $opts->{lang} }{pygments}],
        $strref,
        \$out,
    );
    return undef if $?;
    return $out;
}

sub highlight_string {
    my ($str, $opts) = @_;

    $opts //= {};

    state $langs = [list_languages()];

    for ($opts->{output}) {
        if (!$_) {
            if ($ENV{TERM}) {
                $_ = 'ansi';
            } elsif ($ENV{GATEWAY_INTERFACE} || $ENV{MOD_PERL} || $ENV{PLACK_ENV}) {
                $_ = 'html';
            } else {
                $_ = 'ansi';
            }
        }
        die "Please specify 'ansi' or 'html'" unless /\A(ansi|html)\z/;
    }

    for ($opts->{lang}) {
        $_ //= detect_language($str);
        die "Unsupported lang '$_'" unless $LANGS{$_};
    }

    my $res;

    if ($LANGS{ $opts->{lang} }{sh}) {
        # XXX try_source_highlight_module(\$str, $opts);

        $res = _try_source_highlight_binary(\$str, $opts);
        if (defined $res) {
            $log->trace("Used source-highlight binary to format code");
            return $res;
        }
    }

    if ($LANGS{ $opts->{lang} }{pygments}) {
        $res = _try_pygments_binary(\$str, $opts);
        if (defined $res) {
            $log->trace("Used pygmentize binary to format code");
            return $res;
        }
    }

    die "No syntax highlighting backend is available";
}

sub detect_language {
    my ($code, $opts) = @_;
    $opts //= {};

    die "Sorry, detect_language() not yet implemented, please specify language explicitly for now";
}

sub list_languages {
    sort keys %LANGS;
}

1;
#ABSTRACT: Common interface for syntax highlighting and detecting language in code

=head1 SYNOPSIS

 use SyntaxHighlight::Any qw(highlight_string detect_language);

 my $str = <<'EOT';
 while (<>) {
     $lines++;
     $nonblanks++ if  /\S/;
     $blanks++ unless /\S/;
 }
 EOT
 say highlight_string($str);       # syntax-highlighted code output to terminal
 my @lang = detect_language($str); # => ("perl")


=head1 DESCRIPTION

B<CAVEAT: EARLY DEVELOPMENT MODULE. SOME FUNCTIONS NOT YET IMPLEMENTED. HELP ON
ADDING BACKENDS APPRECATED.>

This module provides a common interface for syntax highlighting and detecting
programming language in code.


=head1 FUNCTIONS

=head2 detect_language($code, \%opts) => LIST

CURRENTLY NOT YET IMPLEMENTED.

Attempt to detect programming language of C<$code> and return zero or more
possible candidates. Return empty list if cannot detect. Die on error (e.g. no
backends available or unexpected output from backend).

C<%opts> is optional. Known options:

=over

=back

=head2 highlight_string($code, \%opts) => STR

Syntax-highlight C<$code> and return the highlighted string. Die on error (e.g.
no backends available or unexpected output from backend). Will choose the
appropriate and available backend which is capable of formatting code in the
specified/detected language and to the specified output.

By default try to detect whether to output HTML code or ANSI codes (see
C<output> option). By default try to detect language of C<$code>.

Backends: currently in general tries B<GNU Source-highlight> (via
L<Syntax::SourceHighlight>, or binary if module not available), then B<Pygments>
(binary). Patches for detecting/using other backends are welcome.

C<%opts> is optional. Known options:

=over

=item * lang => STR

Tell the function what programming language C<$code> should be regarded as. The
list of known languages can be retrieved using C<list_languages()>.

If unspecified, the function will perform the following. For backends which can
detect the language, this function will just give C<$code> to the backend for it
to figure out the language. For backends which cannot detect the language, this
function will first call C<detect_language()>.

B<NOTE: SINCE detect_language()> is not implemented yet, please specify this.>

=item * output => STR

Either C<ansi>, in which syntax-highlighting is done with ANSI escape color
codes, or C<html>. If not specified, will try to detect whether program is
running under terminal (in which case C<ansi> is chosen) or web environment e.g.
under CGI/FastCGI, mod_perl, or Plack (in which case C<html> is chosen). If
detection fails, C<ansi> is chosen.

=back

=head2 list_languages() => LIST

List known languages.


=head1 LANGUAGES

Note: case-sensitive.

 perl
 json
 yaml


=head1 BACKENDS

Currently, the distribution does not pull the backends as dependencies. Please
make sure you install desired backends.


=head1 TODO

=over

=item * Complete list of languages (from Pygments and source-highlight)

=item * Option to select preferred (or change choosing order of) backends

=item * Option: color theme

=item * Function to detect/list available backends

=back


=head1 SEE ALSO

For syntax-highlighting (as well as encoding/formatting) to JSON, there's
L<JSON::Color> or L<Syntax::Highlight::JSON> (despite the module name, the
latter is an encoder, not strictly a string syntax highlighter). For YAML
there's L<YAML::Tiny::Color>.

=cut
