# --
# Copyright (C) 2017 - 2022 Perl-Services.de, https://www.perl-services.de
# Copyright (C) 2026 Freicon GmbH & Co. KG, https://freicon.de/
# --
# Modified by Freicon GmbH & Co. KG, 2026-10-26: ported to OTOBO 11.
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketChecklistCalendarAJAX;

use strict;
use warnings;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::DateTime
    Kernel::System::Log
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::System::Main
    Kernel::System::PerlServices::TicketChecklistStatus
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );


    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Debug} = $ConfigObject->Get('TicketChecklist::Debug');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StatusObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    my $Start = $ParamObject->GetParam( Param => 'start' );
    my $End   = $ParamObject->GetParam( Param => 'end' );

    my ($From, $To);

    if ( $Start !~ m{\A [0-9]+ \z}xms ) {
        $From = sprintf "%s 00:00:00", $Start;
        $To   = sprintf "%s 23:59:59", $End;
    }
    else {
        my $FromValues = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => { Epoch => $Start },
        )->Get();

        my $ToValues = $Kernel::OM->Create(
            'Kernel::System::DateTime',
            ObjectParams => { Epoch => $End },
        )->Get();

        $From = sprintf( "%04d-%02d-%02d 00:00:00", @{$FromValues}{qw(Year Month Day)} );
        $To   = sprintf( "%04d-%02d-%02d 23:59:59", @{$ToValues}{qw(Year Month Day)} );
    }

    if ( $Self->{Debug} ) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => "From: $From // To: $To",
        );
    }

    my $Color = $ConfigObject->Get('TicketChecklist::Calendar::Color') || '#cdcdcd';

    my @Events;

    my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::OpenStates' ) || ['open'];
    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my %ReverseList  = reverse %StatusList;
    my @OpenIDs      = @ReverseList{ @{$OpenStates} };

    my @Items = $ChecklistObject->TaskSearch(
        Start     => $From,
        Stop      => $To,
        StatusIDs => \@OpenIDs,
        UserID    => $Self->{UserID},
    );

    my $Title = $ConfigObject->Get('TicketChecklist::Calendar::TitleFormat') //
        '#[% Data.TicketNumber %] - [% Data.Title %]';

    my $InfoFormat = $ConfigObject->Get('TicketChecklist::Calendar::InfoFormat') //
        '#[% Data.TicketNumber %] - [% Data.Title %]';

    my $URLFormat = sprintf "%sAction=AgentTicketZoom&TicketID=%%s",
        $LayoutObject->{Baselink};

    for my $Item ( @Items ) {
        my $URL = sprintf $URLFormat, $Item->{TicketID};

        $Title = $LayoutObject->Output(
            Template => $Title,
            Data     => $Item,
        );

        $InfoFormat = $LayoutObject->Output(
            Template => $InfoFormat,
            Data     => $Item,
        );

        push @Events, +{
            ID          => "TicketChecklistCalendar-" . $Item->{TicketID},
            Title       => $Title,
            From        => $Item->{DueDate},
            URL         => $URL,
            Description => $InfoFormat,
        };
    }

    if ( $Self->{Debug} ) {
        $LogObject->Log(
            Priority => "notice",
            Message  => $MainObject->Dump( \@Events ),
        );
    } 

    my @EventsForCalendar;
    for my $Event ( @Events ) {
        push @EventsForCalendar, {
            id     => 'checklistticketcalendar-' . $Event->{ID},
            title  => $Event->{Title},
            start  => $Event->{From},
            color  => $Color,
            url    => $Event->{URL},
            allDay => 1,
            desc   => $Event->{Description},
        };
    }

    my $JSON = $LayoutObject->JSONEncode( Data => \@EventsForCalendar );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 0,
    );
}

1;
