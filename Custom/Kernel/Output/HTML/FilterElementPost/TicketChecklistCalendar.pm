# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterElementPost::TicketChecklistCalendar;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Language
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get template name
    my $Templatename = $Param{TemplateFile} || '';

    return 1 if !$Templatename;
    return 1 if !$Param{Templates}->{$Templatename};

    my $LanguageObject = $Kernel::OM->Get('Kernel::Language');
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $JS = sprintf q~
        $(document).ready( function() {
            $('#calendar').fullCalendar(
                'addEventSource',
                {
                    url: Core.Config.Get('Baselink') + "Action=AgentTicketChecklistCalendarAJAX",
                    dataType: 'JSON',
                    success: function (data) {
                        var Container = $('.EventDetailsHiddenContainer');
                        $(data).each( function( index, eventdata ) {
                            var Details = $('<div class="EventDetails" id="event-content-' + eventdata.id + '"></div>');
                            var H3      = $('<h3>%s</h3>');

                            if ( eventdata.desc.substr(0, 1) != "<" ) {
                                eventdata.desc = "<div>" + eventdata.desc + "</div>";
                            }

                            var Infos   = $(eventdata.desc);

                            Details.append( H3 ).append( Infos );
                            Container.append( Details );
                        });
                    }
                }
            );
        });
    ~,
    $LanguageObject->Translate('Event Information');

    $LayoutObject->AddJSOnDocumentComplete( Code => $JS );

    ${ $Param{Data} } =~ s~div \s* class="Hidden \K ~ EventDetailsHiddenContainer~xms;

    return 1;
}

1;
