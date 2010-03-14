package CSS::Prepare::Property::Formatting;

use Modern::Perl;
use CSS::Prepare::Property::Values;



sub parse {
    my %declaration = @_;
    
    my $property = $declaration{'property'};
    my $value    = $declaration{'value'};
    my %canonical;
    my @errors;
    
    my $valid_property_or_error = sub {
            my $type  = shift;
            
            my $sub      = "is_${type}_value";
            my $is_valid = 0;
            
            eval {
                no strict 'refs';
                $is_valid = &$sub( $value );
            };
            
            if ( $is_valid ) {
                $canonical{ $property } = $value;
            }
            else {
                push @errors, {
                        error => "invalid ${type} property: ${value}"
                    };
            }
        };
    
    foreach my $type qw( clear direction display float position ) {
        &$valid_property_or_error( $type )
            if $type eq $property;
    }
    
    my @types = qw( height width max-height min-height max-width min-width );
    foreach my $type ( @types ) {
        &$valid_property_or_error( 'distance' )
            if $type eq $property;
    }
    
    &$valid_property_or_error( 'valign' )
        if 'vertical-align' eq $property;
    
    &$valid_property_or_error( 'lineheight' )
        if 'line-height' eq $property;
    
    &$valid_property_or_error( 'direction' )
        if 'direction' eq $property;
    
    &$valid_property_or_error( 'bidi' )
        if 'unicode-bidi' eq $property;
    
    &$valid_property_or_error( 'zindex' )
        if 'z-index' eq $property;
    
    foreach my $offset qw( top right bottom left ) {
        &$valid_property_or_error( 'offset' )
            if $offset eq $property;
    }
    
    return \%canonical, \@errors;
}
sub output {
    my $block = shift;
    my $output;
    
    my @properties = qw(
            bottom          clear       direction   display
            float           height      left        line-height
            max-height      max-width   min-height  min-width
            position        right       top         unicode-bidi
            vertical-align  width       z-index
        );
    
    foreach my $property ( @properties ) {
        my $value = $block->{ $property };
        
        $output .= "$property:$value;"
            if defined $value;
    }
    
    return $output;
}

1;
