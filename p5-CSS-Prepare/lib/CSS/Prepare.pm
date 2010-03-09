package CSS::Prepare;

use Modern::Perl;

use CSS::Prepare::Property::Background;
use CSS::Prepare::Property::Border;
use CSS::Prepare::Property::Color;
use CSS::Prepare::Property::Font;
use CSS::Prepare::Property::Margin;
use CSS::Prepare::Property::Padding;
use CSS::Prepare::Property::Text;

my @PROPERTIES = qw( Background Border Color Font Margin Padding Text );



# boilerplate new function
sub new {
    my $proto = shift;
    my $args  = shift;
    
    my $class = ref $proto || $proto;
    my $self  = {};
    bless $self, $class;
    
    return $self;
}



sub parse_string {
    my $self   = shift;
    my $string = shift;
    
    return $self->parse( $string )
}
sub output_as_string {
    my $self = shift;
    my @data = @_;
    my $output;
    
    foreach my $block ( @data ) {
        $output .= output_block_as_string( $block );
    }
    
    return $output;
}


sub output_block_as_string {
    my $block = shift;
    
    my $output = '';
    foreach my $property ( @PROPERTIES ) {
        my $string;
        eval {
            no strict 'refs';
    
            my $try_with = "CSS::Prepare::Property::${property}::output";
               $string   = &$try_with( $block->{'block'} );
        };
        if ( defined $string ) {
            $output .= $string;
        }
    }
    
    my $selector = join ',', @{ $block->{'selector'} };
    return "${selector}\{${output}\}\n";
}

sub parse {
    my $self   = shift;
    my $string = shift;
    
    my $stripped     = strip_comments( $string );
       $string       = escape_braces_in_strings( $stripped );
    my @media_blocks = split_into_media_blocks( $string );
    my @declarations;
    
    foreach my $media_block ( @media_blocks ) {
        my @declaration_blocks 
            = split_into_declaration_blocks( $media_block );
        
        foreach my $block ( @declaration_blocks ) {
            # extract from the string a data structure of selectors
            my( $selectors, $selectors_errors )
                = parse_selectors( $block->{'selector'} );
            
            my $declarations       = {};
            my $declaration_errors = [];
            
            # CSS2.1 4.1.6: "the whole statement should be ignored if
            # there is an error anywhere in the selector"
            if ( ! @$selectors_errors ) {
                # extract from the string a data structure of
                # declarations and their properties
                ( $declarations, $declaration_errors )
                    = parse_declaration_block( $block->{'block'} );
            }
            
            push @declarations, {
                    original  => $block->{'block'},
                    selectors => $selectors,
                    errors    => [ 
                        @$selectors_errors, 
                        @$declaration_errors 
                    ],
                    block     => $declarations,
                };
        }
    }
    
    return @declarations;
}
sub strip_comments {
    my $string = shift;
    
    $string =~ s{ \/\* .*? \*\/ }{}gsx;
    
    return $string;
}
sub escape_braces_in_strings {
    my $string = shift;
    
    my $strip_next_string = qr{
            ^
            ( .*?  )        # $1: everything before the string
            ( ['"] )        # $2: the string delimiter
            ( .*?  )        # $3: the content of the string
            (?<! \\ ) \2    # the string delimiter (but not escaped ones)
        }sx;
    
    # find all strings, and tokenise the braces within
    my $return;
    while ( $string =~ s{$strip_next_string}{}sx ) {
        my $before  = $1;
        my $delim   = $2;
        my $content = $3;
        
        $content =~ s{ \{ }{\%-LEFTBRACE-\%}gsx;
        $content =~ s{ \} }{\%-RIGHTBRACE-\%}gsx;
        $return .= "${before}${delim}${content}${delim}";
    }
    $return .= $string;
    
    return $return;
}
sub unescape_braces {
    my $string = shift;
    
    $string =~ s{\%-LEFTBRACE-\%}{\{}gs;
    $string =~ s{\%-RIGHTBRACE-\%}{\}}gs;
    
    return $string;
}
sub split_into_media_blocks {
    my $string = shift;
    my @blocks;
    
    push @blocks, $string;
    
    return @blocks;
}
sub split_into_declaration_blocks {
    my $string = shift;
    my @blocks;
    
    my $splitter = qr{
            ^
            \s*
            (?<selector> .*? )
            \s*
            \{
                (?<block> [^\}]+ )
            \}
        }sx;
    
    while ( $string =~ s{$splitter}{}sx ) {
        my %match = %+;
        push @blocks, \%match;
    }
    
    return @blocks;
}
sub parse_selectors {
    my $string = shift;
    my @selectors;
    
    my $splitter = qr{
            ^
            \s*
            ( [^,]+ )
            \s*
            \,?
        }sx;
    
    while ( $string =~ s{$splitter}{}sx ) {
        # CSS2.1 4.1.6: "the whole statement should be ignored if
        # there is an error anywhere in the selector"
        if ( ! is_valid_selector( $1 ) ) {
            return [], [
                    {
                        error => 'ignored block - '
                               . 'unknown selector (CSS 2.1 #4.1.7)',
                    }
                ];
        }
        else {
            push @selectors, $1;
        }
    }
    
    return \@selectors, [];
}
sub parse_declaration_block {
    my $string = shift;
    my %canonical;
    my @errors;
    
    $string = unescape_braces( $string );
    
    my $splitter = qr{
            ^
            \s*
            (?<property> [^:]+ )
            \:
            \s*
            (?<value> [^;]+ )
            \;?
        }sx;
    
    while ( $string =~ s{$splitter}{}sx ) {
        my %match = %+;
        my $parsed;
        my $errors;
        
        # strip possible extraneous whitespace
        $match{'value'} =~ s{ \s+ $}{}x;
        
        PROPERTY:
        foreach my $property ( @PROPERTIES ) {
            my $found = 0;
            
            eval {
                no strict 'refs';

                my $try_with = "CSS::Prepare::Property::${property}::parse";
                ( $parsed, $errors ) = &$try_with( %match );
            };
            
            push @errors, @$errors
                if @$errors;
            
            last PROPERTY
                if %$parsed or @$errors;
        }
        
        if ( %$parsed ) {
            %canonical = (
                    %canonical,
                    %$parsed
                );
        }
        else {
            if ( ! @$errors ) {
                push @errors, {
                        error => "invalid property '$match{'property'}'"
                    };
            }
        }
    }
    
    return \%canonical, \@errors;
}

sub is_valid_selector {
    my $test = shift;
    
    use re 'eval';
    
    my $nmchar          = qr{ (?: [_a-z0-9-] ) }x;
    my $ident           = qr{ -? [_a-z] $nmchar * }x;
    my $element         = qr{ (?: $ident | \* ) }x;
    my $hash            = qr{ \# $nmchar + }x;
    my $class           = qr{ \. $ident }x;
    my $string          = qr{ (?: \' $ident \' | \" $ident \" ) }x;
    my $pseudo          = qr{
            \:
            (?:
                $ident
                |
                # TODO - I am deliberately ignoring FUNCTION here for now
                # FUNCTION \s* (?: $ident \s* )? \)
                $ident \( .* \)
            )
        }x;
    my $attrib          = qr{
            \[
                \s* $ident \s*
                (?:
                    (?: \= | \~\= | \|\= ) \s*
                    (?: $ident | $string ) \s*
                )?
                \s*
            \]
        }x;
    my $parts           = qr{ (?: $hash | $class | $attrib | $pseudo ) }x;
    my $simple_selector = qr{ (?: $element $parts * | $parts + ) }x;
    my $combinator      = qr{ (?: \+ \s* | \> \s* ) }x;
    my $selector        = qr{
            $simple_selector
            (?:
                $combinator (??{ $selector })
                |
                \s+ (?: $combinator ? (??{ $selector }) )?
            )?
        }x;
    
    
    return 1
        if $test =~ m{^ $selector $}x;
    return 0;
}

1;
