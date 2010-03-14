use Modern::Perl;
use Test::More  tests => 11;

use CSS::Prepare;

my $preparer = CSS::Prepare->new();
my( $css, @structure, $output );


# individual properties work
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'display' => 'none', },
            },
        );
    $css = <<CSS;
div{display:none;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "display property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 
                    'position' => 'absolute', 
                    'top'      => '0', 
                    'right'    => '2em', 
                    'bottom'   => '10px', 
                    'left'     => '10%', 
                },
            },
        );
    $css = <<CSS;
div{bottom:10px;left:10%;position:absolute;right:2em;top:0;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "position property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'float' => 'left', },
            },
        );
    $css = <<CSS;
div{float:left;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "float property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'clear' => 'both', },
            },
        );
    $css = <<CSS;
div{clear:both;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "clear property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'z-index' => '50', },
            },
        );
    $css = <<CSS;
div{z-index:50;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "z-index property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'direction' => 'rtl', },
            },
        );
    $css = <<CSS;
div{direction:rtl;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "direction property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'unicode-bidi' => 'embed', },
            },
        );
    $css = <<CSS;
div{unicode-bidi:embed;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "unicode-bidi property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'vertical-align' => 'text-top', },
            },
        );
    $css = <<CSS;
div{vertical-align:text-top;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "vertical-align property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 'line-height' => '1.8', },
            },
        );
    $css = <<CSS;
div{line-height:1.8;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "line-height property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 
                    'width'     => '50%', 
                    'min-width' => '100px', 
                    'max-width' => '350px', 
                },
            },
        );
    $css = <<CSS;
div{max-width:350px;min-width:100px;width:50%;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "width property was:\n" . $output;
}
{
    @structure = (
            {
                selectors => [ 'div' ],
                block     => { 
                    'height'     => '50%', 
                    'min-height' => '100px', 
                    'max-height' => '350px', 
                },
            },
        );
    $css = <<CSS;
div{height:50%;max-height:350px;min-height:100px;}
CSS
    
    $output = $preparer->output_as_string( @structure );
    ok( $output eq $css )
        or say "height property was:\n" . $output;
}
