# --
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterElementPost::ChecklistSelectArticle;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Output::HTML::Layout
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{UserID} = $Param{UserID};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get template name
    my $Templatename = $Param{TemplateFile};

    return 1 if !$Templatename;
    return 1 if !$Param{Templates}->{$Templatename};

    return 1 if ${ $Param{Data} } !~ m{id="ArticleTable"}xms;
    return 1 if ${ $Param{Data} } =~ m{'input\.ArticleID'}xms;

    # check for checked articles on click
    my $JS = q~
    $('#ArticleTable > tbody > tr').each( function() {
        var InputField = $(this).find('input.ArticleID');
        var ArticleID  = InputField.val();

        var IsLoaded = Core.Config.Get('ChecklistSelectedArticlesLoaded_' + ArticleID );

        if ( IsLoaded ) {
            return;
        }

        var Checkbox = $('<input type="checkbox" name="print_checkbox_' + ArticleID + '" value="' + ArticleID + '" />');

        $(this).find('td.UnreadArticles').append( Checkbox );

        Checkbox.bind( 'click', function(e) {
            var chckbx = $(this);

            $('a[target="print"]').each ( function() {
                var print_link  = $(this);
                var link_target = print_link.attr( 'href' );
                var link_add    = ';ArticleID=' + ArticleID;

                if ( chckbx.is(':checked') ) {
                    link_target += link_add;
                }
                else {
                    link_target = link_target.replace( link_add, "" );
                }

                print_link.attr( 'href', link_target);

            });

            e.stopImmediatePropagation();
        });

        Core.Config.Set('ChecklistSelectedArticlesLoaded_' + ArticleID, 1);
    });
    ~;

    $LayoutObject->AddJSOnDocumentComplete( Code => $JS );

    return 1;
}

1;
