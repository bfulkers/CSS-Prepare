package CSS::Prepare;

use Modern::Perl;

use CSS::Prepare::Property::Background;
use CSS::Prepare::Property::Border;
use CSS::Prepare::Property::Color;
use CSS::Prepare::Property::Effects;
use CSS::Prepare::Property::Font;
use CSS::Prepare::Property::Formatting;
use CSS::Prepare::Property::Generated;
use CSS::Prepare::Property::Margin;
use CSS::Prepare::Property::Padding;
use CSS::Prepare::Property::Tables;
use CSS::Prepare::Property::Text;
use FileHandle;
use File::Basename;
use Storable            qw( dclone );

my @PROPERTIES = qw(
        Background  Border     Color    Effects  Font  Formatting
        Generated   Margin     Padding  Tables   Text
    );



sub new {
    my $class = shift;
    my %args  = @_;
    
    my $self = {
            %args
        };
    bless $self, $class;
    
    my %http_providers = (
            lite => 'HTTP::Lite',
            lwp  => 'LWP::UserAgent',
        );
    
    foreach my $provider ( keys %http_providers ) {
        my $module = $http_providers{ $provider };
        
        eval "require $module";
        unless ($@) {
            $self->{'http_provider'} = $provider;
        }
    }
    
    return $self;
}
sub set_base_directory {
    my $self = shift;
    
    $self->{'base_directory'} = shift;
}
sub get_base_directory {
    my $self = shift;
    
    return $self->{'base_directory'};
}
sub set_base_url {
    my $self = shift;
    
    $self->{'base_url'} = shift;
}
sub get_base_url {
    my $self = shift;
    
    return $self->{'base_url'};
}
sub has_http {
    my $self = shift;
    
    return defined $self->{'http_provider'};
}
sub get_http_provider {
    my $self = shift;
    
    return $self->{'http_provider'};
}

sub parse_file {
    my $self = shift;
    my $file = shift;
    
    my $string = $self->read_file( $file );
    return $self->parse( $string )
        if defined $string;
    
    return;
}
sub parse_file_structure {
    my $self = shift;
    my $file = shift;
    
    my $base = $self->get_base_directory();
    return undef
        unless defined $base && -d $base;
    
    my $stylesheet = basename( $file );
    my $directory  = dirname( $file );
    my @blocks;
    my $path;
    
    foreach my $section ( split m{/}, $directory ) {
           $path  .= "${section}/";
        my $target = "${base}${path}${stylesheet}";
        
        my @file_blocks = $self->parse_file( $target );
        push @blocks, @file_blocks
            if @file_blocks;    # non-existent file is not an error
    }
    
    return @blocks;
}
sub parse_url {
    my $self = shift;
    my $url  = shift;
    
    my $string = $self->read_url( $url );
    return $self->parse( $string )
        if defined $string;
    
    return;
}
sub parse_url_structure {
    my $self = shift;
    my $file = shift;
    
    my $base = $self->get_base_url();
    return undef
        unless defined $base && $base =~ m{https?://};
    
    my $stylesheet = basename( $file );
    my $directory  = dirname( $file );
    my @blocks;
    my $path;
    
    foreach my $section ( split m{/}, $directory ) {
           $path  .= "${section}/";
        my $target = "${base}${path}${stylesheet}";
        
        my @file_blocks = $self->parse_url( $target );
        push @blocks, @file_blocks
            if @file_blocks;    # non-existent url is not an error
    }
    
    return @blocks;
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
    
    my %properties = output_properties( $block->{'block'} );
    my $output     = join '', sort keys %properties;
    my $selector   = join ',', @{ $block->{'selectors'} };
    
    return "${selector}\{${output}\}\n";
}
sub output_properties {
    my $block = shift;
    
    my %properties;
    foreach my $property ( @PROPERTIES ) {
        my $string;
        
        eval {
            no strict 'refs';
            
            my $try_with = "CSS::Prepare::Property::${property}::output";
               $string   = &$try_with( $block );
        };
        
        $properties{ $string }++
            if defined $string;
    }
    
    return %properties;
}

sub get_stylesheet {
    
}
sub read_file {
    my $self = shift;
    my $file = shift;
    
    my $handle = FileHandle->new( $file );
    if ( defined $handle ) {
        local $/;
        
        return <$handle>;
    }
    
    return;
}
sub read_url {
    my $self = shift;
    my $url  = shift;
    
    my $provider = $self->get_http_provider();
    given ( $provider ) {
        when ( 'lite' ) { return $self->get_url_lite( $url ); }
        when ( 'lwp'  ) { return $self->get_url_lwp( $url ); }
    }
    
    return;
}
sub get_url_lite {
    my $self = shift;
    my $url  = shift;
    
    my $http = HTTP::Lite->new();
    my $code = $http->request( $url );
    
    given ( $code ) {
        when ( 200 ) { return $http->body(); }
        when ( 404 ) { return; }
        default {
            # TODO proper error handling
            die "http code $code";
        }
    }
}
sub get_url_lwp {
    my $self = shift;
    my $url  = shift;
    
    my $http = LWP::UserAgent->new();
    my $resp = $http->get( $url );
    my $code = $resp->code();
    
    given ( $code ) {
        when ( 200 ) { return $resp->decoded_content(); }
        when ( 404 ) { return; }
        default {
            # TODO proper error handling
            die $resp->status_line;
        }
    }
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
                    original  => unescape_braces( $block->{'block'} ),
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

sub optimise {
    my $self = shift;
    my @data = @_;
    
    my %styles     = $self->sort_blocks_into_hash( @data );
    my @properties = array_of_properties( %styles );
    my %state      = get_optimal_state( @properties );
    my @optimised  = $self->get_blocks_from_state( %state );
    
    return @optimised;
}
sub sort_blocks_into_hash {
    my $self = shift;
    my @data = @_;
    
    my %styles;
    foreach my $block ( @data ) {
        foreach my $property ( keys %{ $block->{'block'} } ) {
            my $value = $block->{'block'}{ $property };
            
            foreach my $selector ( @{ $block->{'selectors'} } ) {
                $styles{ $selector }{ $property } = $value;
            }
        }
    }
    
    return %styles;
}
sub array_of_properties {
    my %styles = @_;
    
    my @properties;
    
    foreach my $selector ( keys %styles ) {
        my %properties = output_properties( $styles{ $selector } );
        
        foreach my $property ( keys %properties ) {
            push @properties, $selector, $property;
        }
    }
    
    return @properties;
}
sub get_optimal_state {
    my @properties = @_;
    
    my %by_property   = get_selectors_by_property( @properties );
    my $found_savings = 1;
    my $total_savings = 0;
    
    while ( $found_savings ) {
        ( $found_savings, %by_property )
            = mix_biggest_properties( %by_property );
        
        $total_savings += $found_savings;
    }
    
    return %by_property;
}
sub get_selectors_by_property {
    my @properties = @_;
    
    my %by_property;
    while ( @properties ) {
        my $selector = shift @properties;
        my $property = shift @properties;
        
        $by_property{ $property }{ $selector } = 1;
    }
    
    return %by_property;
}
sub mix_biggest_properties {
    my %by_property = @_;
    
    my $num_children = sub {
            my $a_children = scalar keys %{$by_property{ $a }};
            my $b_children = scalar keys %{$by_property{ $b }};
            return $b_children <=> $a_children;
        };
    my @sorted_properties = sort $num_children keys %by_property;
    
    foreach my $property ( @sorted_properties ) {
        my( $mix_with, $saving )
            = get_biggest_saving_if_mixed( $property, %by_property );
            
        if ( defined $mix_with ) {
            my %properties
                = mix_properties( $property, $mix_with, %by_property );
            return( $saving, %properties );
        }
    }
    
    return( 0, %by_property );
}
sub get_biggest_saving_if_mixed {
    my $property   = shift;
    my %properties = @_;
    
    my $unmixed_property_length
        = output_string_length( $property, keys %{$properties{ $property }} );
    my %savings;
    
    foreach my $examine ( keys %properties ) {
        next if $property eq $examine;
        
        my @common_selectors
            = get_common_selectors( $property, $examine, %properties );
        my @property_remaining
            = get_remaining_selectors( $examine, $property, %properties );
        my @examine_remaining
            = get_remaining_selectors( $property, $examine, %properties );
        
        my $unmixed_examine_length
            = output_string_length(
                  $examine, keys %{$properties{ $examine }} );
        my $mixed_common_length
            = output_string_length( "$property,$examine", @common_selectors );
        my $mixed_selector_length
            = output_string_length( $property, @property_remaining );
        my $mixed_examine_length
            = output_string_length( $examine, @examine_remaining );
        
        my $unmixed = $unmixed_property_length + $unmixed_examine_length;
        my $mixed   = $mixed_common_length
                      + $mixed_selector_length
                      + $mixed_examine_length;
        
        $savings{ $examine }
            = ( $unmixed - $mixed );
    }
    
    my $largest_value = 0;
    my $largest;
    foreach my $key ( keys %savings ) {
        my $value = $savings{ $key };
        
        if ( $value > $largest_value ) {
            $largest_value = $value;
            $largest       = $key;
        }
    }
    
    return( $largest, $largest_value );
}
sub output_string_length {
    my $property  = shift;
    my @selectors = @_;
    
    return 0
        unless scalar @selectors;
    
    my $string = sprintf '%s{%s}',
            join( ',', @selectors ),
            $property;
    
    return length $string;
}
sub get_common_selectors {
    my $property   = shift;
    my $examine    = shift;
    my %properties = @_;
    
    my @common = grep {
            $_ if defined $properties{ $property }{ $_};
        } keys %{$properties{ $examine }};
    
    return @common;
}
sub get_remaining_selectors {
    my $property   = shift;
    my $examine    = shift;
    my %properties = @_;
    
    my @remaining = grep {
            $_ if !defined $properties{ $property }{ $_};
        } keys %{$properties{ $examine }};
    
    return @remaining;
}
sub mix_properties {
    my $property   = shift;
    my $mix_with   = shift;
    my %properties = @_;
    
    my $mixed_property = join '', sort( $property, $mix_with );
    my @common_selectors
        = get_common_selectors( $property, $mix_with, %properties );
    
    foreach my $selector ( @common_selectors ) {
        $properties{ $mixed_property }{ $selector } = 1;
        delete $properties{ $property }{ $selector };
        delete $properties{ $mix_with }{ $selector };
    }
    
    delete $properties{ $property }
        unless scalar keys %{$properties{ $property }};
    delete $properties{ $mix_with }
        unless scalar keys %{$properties{ $mix_with }};
    
    return %properties;
}
sub get_blocks_from_state {
    my $self       = shift;
    my %properties = @_;
    
    my @blocks;
    foreach my $property ( sort keys %properties ) {
        my @selectors = sort keys %{$properties{ $property }};
        my $css       = join( ',', @selectors )
                      . "{$property}";
        
        push @blocks, $self->parse_string( $css );
    }
    
    return @blocks;
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
