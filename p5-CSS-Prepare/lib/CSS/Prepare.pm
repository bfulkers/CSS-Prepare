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
    my @media_blocks = split_into_media_blocks( $stripped );
    my @declarations;
    
    foreach my $media_block ( @media_blocks ) {
        my @declaration_blocks 
            = split_into_declaration_blocks( $media_block );
        
        foreach my $block ( @declaration_blocks ) {
            # replace the string with a data
            # structure of selectors
            $block->{'selector'} = parse_selectors( $block->{'selector'} );
            
            # replace the string with a data structure of
            # declarations and their properties
            $block->{'block'} 
                = parse_declaration_block( $block->{'block'} );
            
            push @declarations, $block;
        }
    }
    
    return @declarations;
}
sub strip_comments {
    my $string = shift;
    
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
        push @selectors, $1;
    }
    
    return \@selectors;
}
sub parse_declaration_block {
    my $string = shift;
    my %canonical;
    
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
        my %parsed;
        
        PROPERTY:
        foreach my $property ( @PROPERTIES ) {
            my $found = 0;
            
            eval {
                no strict 'refs';

                my $try_with = "CSS::Prepare::Property::${property}::parse";
                   %parsed   = &$try_with( %match );
            };
            
            if ( %parsed ) {
                last PROPERTY;
            }
        }
        
        if ( %parsed ) {
            %canonical = (
                    %canonical,
                    %parsed
                );
        }
        # what breaks without the fall-through?
        # else {
        #     %canonical = (
        #             %canonical,
        #             $match{'property'} => $match{'value'},
        #         );
        # }
    }
    
    return \%canonical;
}

1;