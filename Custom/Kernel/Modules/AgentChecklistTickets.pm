# --
# Kernel/Modules/AgentChecklistTickets.pm - status for all open tickets
# Copyright (C) 2014 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentChecklistTickets;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::Output::HTML::Layout
    Kernel::System::Web::Request
    Kernel::System::JSON
    Kernel::System::AuthSession
    Kernel::System::DynamicField
    Kernel::System::PerlServices::TicketChecklist
);

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Config} = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");
    $Self->{Filter} = $ParamObject->GetParam( Param => 'Filter' ) || 'Open';
    $Self->{View}   = $ParamObject->GetParam( Param => 'View' ) || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SessionObject   = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    # store last queue screen
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenOverview',
        Value     => $Self->{RequestedURL},
    );

    # define filter
    my %Filters = (
        Open => {
            Name   => 'Tickets/Open Checklists',
            Prio   => 1000,
            Search => {
                Types  => 'open',
                UserID => $Self->{UserID},
            },
        },
        Closed => {
            Name   => 'Tickets/Other Checklists',
            Prio   => 1001,
            Search => {
                Types  => 'closed',
                UserID => $Self->{UserID},
            },
        },
    );

    # check if filter is valid
    if ( !$Filters{ $Self->{Filter} } ) {
        $LayoutObject->FatalError( Message => "Invalid Filter: $Self->{Filter}!" );
    }

    # do shown tickets lookup
    my $Limit = 10_000;

    my @ViewableTickets = $ChecklistObject->TicketSearch(
        %{ $Filters{ $Self->{Filter} }->{Search} },
        Result => 'ARRAY',
    );

    my $ViewableTicketCount = $ChecklistObject->TicketSearch(
        %{ $Filters{ $Self->{Filter} }->{Search} },
        Result => 'COUNT',
    );

    if ( $ViewableTicketCount > $Limit ) {
        $ViewableTicketCount = $Limit;
    }

    # do nav bar lookup
    my %NavBarFilter;
    for my $Filter ( sort keys %Filters ) {
        my $Count = $ChecklistObject->TicketSearch(
            %{ $Filters{$Filter}->{Search} },
            Result => 'COUNT',
        );

        if ( $Count > $Limit ) {
            $Count = $Limit;
        }

        $NavBarFilter{ $Filters{$Filter}->{Prio} } = {
            Count  => $Count,
            Filter => $Filter,
            %{ $Filters{$Filter} },
        };
    }

    # show ticket's
    my $LinkPage = 'Filter='
        . $LayoutObject->Ascii2Html( Text => $Self->{Filter} )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
        . ';';

    my $Output = $LayoutObject->Header(
        Title => 'Checklist Tickets',
    );

    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->TicketListShow(
        TicketIDs         => \@ViewableTickets,
        OriginalTicketIDs => \@ViewableTickets,
        Action            => 'AgentChecklistTickets',
        RequestedURL      => $Self->{RequestedURL},
        Total             => $ViewableTicketCount,
        Env               => $Self,
        LinkPage          => $LinkPage,
        View              => $Self->{View},
        Limit             => $Limit,
        TitleName         => 'Checklist Tickets',
        TitleValue        => $Filters{ $Self->{Filter} }->{Name},
        Filter            => $Self->{Filter},
        Filters           => \%NavBarFilter,
        Output            => 1,
    );

    $Output =~ s{<a \s+ name="OverviewControl" [^>]*? SortBy= [^>]*? >(.*?)</a>}{$1}xmsg;

    # get page footer
    $Output .= $LayoutObject->Footer();

    # return page
    return $Output;
}

1;
