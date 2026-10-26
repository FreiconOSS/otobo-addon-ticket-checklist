# --
# Kernel/Modules/AgentTicketChangeChecklistStatus.pm - manage the checklist for a ticket
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketChangeChecklistStatus;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Output::HTML::Layout
    Kernel::System::Ticket
    Kernel::System::User
    Kernel::System::Web::Request
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistStatus
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{Config}->{Permission} = 'ro';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $StatusObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

    my $ID   = $ParamObject->GetParam( Param => 'ID' );
    my %Item = $ChecklistObject->TicketChecklistGet(
        ID => $ID,
    );

    my $TicketID = $ParamObject->GetParam( Param => 'TicketID' );
    my %Ticket   = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID   => $Self->{UserID},
    );

    my $AllAgentsStatusChange = $ConfigObject->Get('TicketChecklist::AllAgentsStatusChange');

    if ( %Item && %Ticket ) {
        delete $Item{Status};

        my %UserData = $UserObject->GetUserData( UserID => $Self->{UserID} );

        my $UseAutocomplete    = $ConfigObject->Get('TicketChecklist::ResponsibleAutocomplete');
        my $AutocompleteModule = $ConfigObject->Get('TicketChecklist::ResponsibleAutocompleteModule') // 'Agent';

        my @PossibleValues;

        if ( $UseAutocomplete ) {
            my $AutocompleteObject = $Kernel::OM->Get(
               'Kernel::System::PerlServices::TicketChecklist::Autocomplete::' . $AutocompleteModule
            );

            @PossibleValues = $AutocompleteObject->MemberOfList(
                %UserData,
            );
        }

        $Item{ResponsibleKey} //= '';

        my $IsResponsible =
            $Item{ResponsibleID} == $Self->{UserID} ||
            grep{ $_ eq $Item{ResponsibleKey} }@PossibleValues;

        if (
            ( $Item{ResponsibleID} == 1 && !$Item{ResponsibleKey} ) ||
            ( !$Item{ResponsibleID} && $AutocompleteModule eq 'Agent' &&
                ($Item{ResponsibleKey} == $Self->{UserID} || $Item{ResponsibleKey} == 1 ) ) ||
            ( !$Item{ResponsibleID} && !$Item{ResponsibleKey} )
        ) {
            $IsResponsible = 1;
        }

        if ( $AllAgentsStatusChange ) {
            $IsResponsible = 1;
        }


        if ( $Ticket{OwnerID} == $Self->{UserID} || $IsResponsible ) {
            $Item{StatusID} = $ParamObject->GetParam( Param => 'Status' );
            my $ChangeNote  = $ParamObject->GetParam( Param => 'ChangeNote' );

            $ChecklistObject->TicketChecklistUpdate(
                %Item,
                ChangeNote => $ChangeNote,
                UserID     => $Self->{UserID},
            );
        }

        my %Status = $StatusObject->TicketChecklistStatusGet( ID => $Item{StatusID} );
        my $Pos    = $ParamObject->GetParam( Param => 'ItemPosition' );

        my %UpdatedItem = $ChecklistObject->TicketChecklistGet(
            ID => $ID,
        );

        my $JSON   = $LayoutObject->JSONEncode(
            Data => {
                Position   => $Pos,
                Color      => $Status{Color},
                ChangeNote => $UpdatedItem{ChangeNote},
            },
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
}

1;
